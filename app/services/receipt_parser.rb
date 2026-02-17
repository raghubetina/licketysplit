class ReceiptParser
  attr_reader :image_urls

  SYSTEM_INSTRUCTIONS = <<~INSTRUCTIONS
    You are a receipt parser. Read the receipt images using your built-in \
    vision — do NOT use code interpreter on your first attempt. Just look \
    at the images and extract the data. Only use code interpreter if your \
    first read has text that is too blurry or small to make out, and you \
    need to crop or zoom in for clarity. Never use code interpreter for OCR. \
    Extract structured data following the provided JSON schema exactly. \
    Be precise with numbers and maintain data integrity. When in doubt about \
    ambiguous text, make reasonable assumptions based on typical restaurant \
    receipt patterns. \
    You may receive multiple images of the same receipt (e.g. a long receipt \
    photographed in sections). Combine all images into a single coherent result. \
    The images may not be in order — use context clues like item numbering, \
    subtotals, and totals to determine the correct sequence. \
    Do not duplicate items that appear in overlapping regions of multiple photos.
  INSTRUCTIONS

  USER_PROMPT = <<~PROMPT
    Your job is to extract structured data from images of restaurant receipts.

    - You may receive one or more images. If there are multiple images, they are all part of the same receipt — combine them into a single unified result.
    - Descriptions should be clean item names without quantity or price info (e.g. 'CB - Combo' not 'CB x 2 - Combo ($7.85 each)') - extract quantity and unit_price to their own fields.
    - Addons (modifications like 'Extra cheese', 'Add bacon') belong in the parent item's addons array, not as separate line items.
    - Addon descriptions should also be clean (e.g. 'Grilled Onion' not 'Grilled Onion ($0.75)') - extract the price to unit_price and total_price fields.
    - Taxes (e.g. sales tax, VAT, GST) should be included as global fees with fee_type "tax".
    - Surcharges (e.g. health insurance surcharge, service fee, delivery fee) should be included as global fees with fee_type "other".
    - Tip/gratuity should be included as a global fee with fee_type "tip".
    - Check-wide discounts (e.g. '10% off Tuesdays') should be included as global discounts.
    - Item-specific discounts (e.g. if an item was comped) should be included within the corresponding line item, and a description/reason for the discount should be included if available.
    - The value for discounts should be reported as positive numbers, even if they are printed on the receipt as negative numbers.
    - Default quantity to 1 if unclear.
  PROMPT

  def initialize(image_urls)
    @image_urls = Array(image_urls).map(&:to_s)
  end

  def parse(&on_event)
    stream = client.responses.stream(
      model: "gpt-5.2",
      instructions: SYSTEM_INSTRUCTIONS,
      input: build_input,
      tools: [{type: :code_interpreter, container: {type: :auto}}],
      text: {format: {type: :json_schema, **receipt_schema}},
      reasoning: {effort: :low, summary: :detailed}
    )

    stream.each do |event|
      next unless on_event

      case event
      when OpenAI::Models::Responses::ResponseReasoningSummaryTextDeltaEvent
        on_event.call(:reasoning, event.delta)
      when OpenAI::Models::Responses::ResponseReasoningSummaryPartDoneEvent
        on_event.call(:reasoning, "\n\n")
      end
    end

    response_json = JSON.parse(stream.get_output_text, symbolize_names: true)
    transform_to_check_attributes(response_json)
  end

  private

  def client
    @client ||= OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
  end

  def build_input
    content = [{type: :input_text, text: USER_PROMPT}]

    image_urls.each do |url|
      content << {type: :input_image, image_url: url, detail: :high}
    end

    [{role: :user, content: content}]
  end

  def receipt_schema
    {
      name: "receipt_data",
      strict: true,
      schema: {
        type: "object",
        properties: {
          restaurant: {
            type: "object",
            description: "Details of the restaurant",
            properties: {
              name: {
                type: ["string", "null"],
                description: "Name of the restaurant"
              },
              address: {
                type: ["string", "null"],
                description: "Address of the restaurant"
              },
              phone: {
                type: ["string", "null"],
                description: "Phone number of the restaurant"
              }
            },
            required: ["name", "address", "phone"],
            additionalProperties: false
          },
          billed_on: {
            type: ["string", "null"],
            description: "Datetime when the bill was issued (ISO 8601 format)"
          },
          currency: {
            type: "string",
            description: "Currency code (ISO 4217), e.g. 'USD', 'EUR', 'INR', 'MXN', 'CAD'",
            default: "USD"
          },
          line_items: {
            type: "array",
            description: "List of line items on the receipt, in order they appear",
            items: {
              type: "object",
              description: "Single line item on the receipt",
              properties: {
                position: {
                  type: "integer",
                  minimum: 1,
                  description: "Position of the item on the receipt (1 for first item, 2 for second, etc.)"
                },
                description: {
                  type: "string",
                  description: "Full description of the item"
                },
                quantity: {
                  type: "integer",
                  minimum: 1,
                  description: "Quantity of the item ordered"
                },
                unit_price: {
                  type: "number",
                  minimum: 0,
                  description: "Price per single unit of the item"
                },
                total_price: {
                  type: "number",
                  minimum: 0,
                  description: "Total price for this line item (quantity * unit price minus discounts)"
                },
                line_item_discount: {
                  type: ["number", "null"],
                  minimum: 0,
                  description: "Discount applied to this line item"
                },
                line_item_discount_description: {
                  type: ["string", "null"],
                  description: "Description or reason for line item discount"
                },
                addons: {
                  type: "array",
                  description: "List of addons associated with this line item",
                  items: {
                    type: "object",
                    description: "Single addon for a line item",
                    properties: {
                      description: {
                        type: "string",
                        description: "Description of the addon"
                      },
                      quantity: {
                        type: "integer",
                        minimum: 1,
                        description: "Quantity of the addon"
                      },
                      unit_price: {
                        type: "number",
                        minimum: 0,
                        description: "Price per single addon unit"
                      },
                      total_price: {
                        type: "number",
                        minimum: 0,
                        description: "Total price for this addon (quantity * unit price minus discounts)"
                      },
                      addon_discount: {
                        type: ["number", "null"],
                        minimum: 0,
                        description: "Discount applied to this addon"
                      },
                      addon_discount_description: {
                        type: ["string", "null"],
                        description: "Description or reason for addon discount"
                      }
                    },
                    required: [
                      "description",
                      "quantity",
                      "unit_price",
                      "total_price",
                      "addon_discount",
                      "addon_discount_description"
                    ],
                    additionalProperties: false
                  }
                }
              },
              required: [
                "position",
                "description",
                "quantity",
                "unit_price",
                "total_price",
                "line_item_discount",
                "line_item_discount_description",
                "addons"
              ],
              additionalProperties: false
            }
          },
          global_discounts: {
            type: "array",
            description: "List of global (check-wide) discounts",
            items: {
              type: "object",
              properties: {
                description: {
                  type: "string",
                  description: "Description of the global discount"
                },
                amount: {
                  type: "number",
                  minimum: 0,
                  description: "Amount of the global discount"
                }
              },
              required: ["description", "amount"],
              additionalProperties: false
            }
          },
          subtotal_before_fees: {
            type: "number",
            minimum: 0,
            description: "Subtotal amount before fees and discounts"
          },
          global_fees: {
            type: "array",
            description: "List of global fees (taxes, surcharges, tips)",
            items: {
              type: "object",
              properties: {
                description: {
                  type: "string",
                  description: "Description of the global fee"
                },
                amount: {
                  type: "number",
                  minimum: 0,
                  description: "Amount of the global fee"
                },
                fee_type: {
                  type: "string",
                  enum: ["tip", "tax", "other"],
                  description: "Type of fee: 'tip' for gratuity, 'tax' for sales tax/VAT/GST, 'other' for surcharges/service fees"
                }
              },
              required: ["description", "amount", "fee_type"],
              additionalProperties: false
            }
          },
          grand_total: {
            type: "number",
            minimum: 0,
            description: "Total amount after fees and discounts"
          }
        },
        required: [
          "restaurant",
          "billed_on",
          "currency",
          "line_items",
          "global_discounts",
          "subtotal_before_fees",
          "global_fees",
          "grand_total"
        ],
        additionalProperties: false
      }
    }
  end

  def transform_to_check_attributes(parsed_data)
    currency_code = parsed_data[:currency] || "USD"
    {
      restaurant_name: parsed_data[:restaurant][:name],
      restaurant_address: parsed_data[:restaurant][:address],
      restaurant_phone_number: parsed_data[:restaurant][:phone],
      billed_on: parse_date(parsed_data[:billed_on]),
      grand_total: parsed_data[:grand_total],
      currency: currency_code,
      currency_symbol: currency_symbol_for(currency_code),
      status: "reviewing",
      line_items_attributes: transform_line_items(parsed_data[:line_items]),
      global_fees_attributes: parsed_data[:global_fees].map { |fee|
        {description: fee[:description], amount: fee[:amount], fee_type: fee[:fee_type]}
      },
      global_discounts_attributes: parsed_data[:global_discounts].map { |discount|
        {description: discount[:description], amount: discount[:amount]}
      }
    }
  end

  def currency_symbol_for(code)
    currency = Money::Currency.find(code)
    return "$" unless currency

    currency.symbol
  end

  def transform_line_items(items)
    items.map do |item|
      line_item = {
        position: item[:position],
        description: item[:description],
        quantity: item[:quantity],
        unit_price: item[:unit_price],
        total_price: item[:total_price]
      }

      if item[:line_item_discount] && item[:line_item_discount] > 0
        line_item[:discount] = item[:line_item_discount]
        line_item[:discount_description] = item[:line_item_discount_description]
      end

      if item[:addons].any?
        line_item[:addons_attributes] = item[:addons].map do |addon_data|
          addon = {
            description: addon_data[:description],
            quantity: addon_data[:quantity],
            unit_price: addon_data[:unit_price],
            total_price: addon_data[:total_price]
          }

          if addon_data[:addon_discount] && addon_data[:addon_discount] > 0
            addon[:discount] = addon_data[:addon_discount]
            addon[:discount_description] = addon_data[:addon_discount_description]
          end

          addon
        end
      end

      line_item
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    DateTime.parse(date_string)
  rescue ArgumentError
    nil
  end
end
