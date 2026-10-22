class ReceiptParser
  attr_reader :sources

  SYSTEM_INSTRUCTIONS = <<~INSTRUCTIONS
    You turn receipts -- photos or PDFs -- into the data a bill-splitting app
    works from. Each person claims the line items they had, and the app splits
    fees and check-wide discounts in proportion. So every amount must land on
    the item it belongs to, and the total the app computes must be what was
    actually paid.

    Before answering, check that the line items (unit_price × quantity, minus
    their discount, plus their addons), minus global_discounts, plus
    global_fees, equal grand_total, and that grand_total is what the customer
    actually owes. If they don't, look for a discount counted twice, a fee
    left out, or a price paired with the wrong line.

    Reading the receipt
    - Read the images directly. Use code interpreter only to crop or zoom
      into text too small or blurry to read.
    - Prices are often printed a line above or below their item, or in a
      column that drifts. Pair each price with its item using the arithmetic
      -- quantities, subtotals -- rather than the row it happens to sit on.
    - Several files may be parts of one long receipt, out of order and
      overlapping: order them by item sequence and totals, and record each
      item once. Or they may be different receipts from the same outing:
      include every item from all of them, with grand_total the sum of their
      totals.
    - Ignore suggested-tip tables, cash tendered, change, and payment lines.

    Line items and addons
    - A line printed as its own item -- at item-level indentation, usually
      with its own quantity -- is a line item, even if its name starts with
      "Add". Keep receipt order, and keep $0 items.
    - A line printed as a modification of the item above it (indented
      beneath it, or marked with +, -, >, * or similar) is an addon of that
      item. If the layout doesn't make clear which item it modifies, make it
      a line item instead: people can assign a line item themselves, but an
      addon under the wrong item bills the wrong person.
    - description is the clean item name, without quantity or price text.
      quantity counts whole units and unit_price is the price of one, so
      "2 @ 7.50 15.00" is quantity 2 at 7.50. Identical items printed on
      separate lines stay separate line items.
    - A modifier price printed inside its item's price ("Burger 8.35 /
      Grilled Onion (0.75)") is split out: the item at 7.60, the addon 0.75.
    - An item sold by weight or measure ("2.15 lb @ 4.29/lb 9.22") is
      quantity 1 at the amount actually charged (9.22), with the weight and
      rate kept in the description. Items sold in whole units keep their real
      quantity.

    Discounts
    - Report discounts as positive numbers, however the receipt prints them.
    - A discount or comp the receipt ties to one item -- printed beneath it
      as its modifier, naming it, or stated as a share of its price -- is
      that item's discount. Any other -- a coupon, promotion, check-wide
      percentage, or a comp or void printed as its own line -- is a global
      discount, even when its amount happens to equal some item's price.
    - Prices that already include a promotion (a struck-through original
      beside the charged price, or savings marked as already applied) are
      recorded as charged, with no global discount for that promotion:
      recording both takes it off twice.

    Fees, tips and the total
    - Each tax line is a fee of type "tax". When prices already include tax
      (VAT included, items marked tax-included), record only tax charged on
      top.
    - Every tip or gratuity -- automatic, voluntary, printed or handwritten
      -- is a fee of type "tip", even when the receipt prints an automatic
      gratuity as if it were an item.
    - Service charges, surcharges, and delivery, processing or take-out fees
      are fees of type "other". A per-person cover charge printed as an item
      stays a line item.
    - Receipts are often amended by hand after printing: a tip written on
      the tip line, a new total below the printed one. Handwritten amounts
      are authoritative -- record the written tip as a "tip" fee and use the
      written total as grand_total; if only a new total is written, the
      difference from the printed total is the tip. Look for this even when
      the printed total already adds up. A blank tip line means no tip.
  INSTRUCTIONS

  USER_PROMPT = "Extract the data from this receipt."

  MissingImagesError = Class.new(StandardError)

  PDF_CONTENT_TYPE = "application/pdf"

  MODEL = "gpt-6.1-sol"
  REASONING_EFFORT = :low
  SERVICE_TIER = :auto

  attr_reader :model, :reasoning_effort, :service_tier, :response

  # The keywords exist so the receipt eval can compare candidates
  # (bin/rails receipts:eval); production always parses with the defaults
  # above.
  def initialize(sources, model: MODEL, reasoning_effort: REASONING_EFFORT, service_tier: SERVICE_TIER)
    @sources = Array(sources).filter_map { |source| normalize_source(source) }
    @model = model
    @reasoning_effort = reasoning_effort
    @service_tier = service_tier
  end

  def parse(&on_event)
    # Without a receipt the model still returns a schema-valid result -- zero line
    # items, zero total -- and the parse reports success. Fail instead of
    # spending a vision call to produce an empty check.
    raise MissingImagesError, "No receipt images to parse" if sources.empty?

    stream = client.responses.stream(
      model: model,
      instructions: SYSTEM_INSTRUCTIONS,
      input: build_input,
      tools: [{type: :code_interpreter, container: {type: :auto}}],
      text: {format: {type: :json_schema, **receipt_schema}},
      reasoning: {effort: reasoning_effort, summary: :auto},
      service_tier: service_tier
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

    @response = stream.get_final_response
    response_json = JSON.parse(stream.get_output_text, symbolize_names: true)
    transform_to_check_attributes(response_json)
  end

  private

  def client
    @client ||= OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
  end

  # A PDF is handed over whole rather than as page images: OpenAI renders every
  # page and also passes the embedded text layer, which reads a dense multi-page
  # invoice more accurately than a rasterized page does.
  def build_input
    content = [{type: :input_text, text: USER_PROMPT}]

    sources.each do |source|
      content << if source[:content_type] == PDF_CONTENT_TYPE
        {type: :input_file, file_url: source[:url]}
      else
        {type: :input_image, image_url: source[:url], detail: :high}
      end
    end

    [{role: :user, content: content}]
  end

  # Checks pass {url:, content_type:} so a PDF can be told from a photo; the
  # receipt-parsing rake task passes bare image URLs.
  def normalize_source(source)
    url, content_type = source.is_a?(Hash) ? source.values_at(:url, :content_type) : [source, nil]
    return if url.blank?

    {url: url.to_s, content_type: content_type}
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
                  description: "Item name, without quantity or price"
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
      global_fees_attributes: combine_tips(parsed_data[:global_fees]).map { |fee|
        {description: fee[:description], amount: fee[:amount], fee_type: fee[:fee_type]}
      },
      global_discounts_attributes: parsed_data[:global_discounts].map { |discount|
        {description: discount[:description], amount: discount[:amount]}
      }
    }
  end

  # A check holds one tip -- saving a tip fee destroys any other -- so an
  # automatic gratuity plus a tip written in by hand would silently lose the
  # first. Fold every tip on the receipt into a single fee instead.
  def combine_tips(fees)
    tips, others = fees.partition { |fee| fee[:fee_type] == "tip" }
    return fees if tips.size < 2

    others + [{
      description: tips.pluck(:description).join(" + "),
      amount: tips.sum { |tip| tip[:amount] }.round(2),
      fee_type: "tip"
    }]
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
