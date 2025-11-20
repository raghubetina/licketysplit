require "ai-chat"

class ReceiptParser
  attr_reader :image_path, :chat

  def initialize(image_path)
    @image_path = image_path.to_s
    @chat = AI::Chat.new
  end

  def parse
    configure_chat

    chat.system(
      "You are a receipt parser. Extract structured data from receipt images " \
      "following the provided JSON schema exactly. Be precise with numbers and " \
      "maintain data integrity. When in doubt about ambiguous text, make reasonable " \
      "assumptions based on typical restaurant receipt patterns."
    )

    chat.user(
      "Your job is to extract structured data from images of restaurant receipts.\n\n" \
      "- Addons (modifications like 'Extra cheese', 'Add bacon') belong in the parent item's addons array, not as separate line items.\n" \
      "- Addon prices are often shown inline (e.g. 'Grilled Onion ($0.75)') - extract 0.75 to the addon's unit_price and total_price fields.\n" \
      "- Taxes (e.g. sales tax) should be included as global fees.\n" \
      "- Surcharges (e.g. health insurance surcharge) should be included as global fees.\n" \
      "- Tip/gratuity should be included as a global fee.\n" \
      "- Check-wide discounts (e.g. '10% off Tuesdays') should be included as global discounts.\n" \
      "- Item-specific discounts (e.g. if an item was comped) should be included within the corresponding line item, and a description/reason for the discount should be included if available.\n" \
      "- The value for discounts should be reported as positive numbers, even if they are printed on the receipt as negative numbers.\n" \
      "- Default quantity to 1 if unclear.",
      image: image_path
    )

    response = chat.generate![:content]
    transform_to_check_attributes(response)
  rescue => e
    Rails.logger.error "Receipt parsing failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def configure_chat
    chat.model = "gpt-5.1"
    chat.reasoning_effort = "low"
    chat.schema = receipt_schema
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
            description: "Currency code (ISO 4217)",
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
                }
              },
              required: ["description", "amount"],
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
    {
      restaurant_name: parsed_data[:restaurant][:name],
      restaurant_address: parsed_data[:restaurant][:address],
      restaurant_phone_number: parsed_data[:restaurant][:phone],
      billed_on: parse_date(parsed_data[:billed_on]),
      grand_total: parsed_data[:grand_total],
      currency: parsed_data[:currency],
      status: "reviewing",
      line_items_attributes: transform_line_items(parsed_data[:line_items]),
      global_fees_attributes: parsed_data[:global_fees].map { |fee|
        {description: fee[:description], amount: fee[:amount]}
      },
      global_discounts_attributes: parsed_data[:global_discounts].map { |discount|
        {description: discount[:description], amount: discount[:amount]}
      }
    }
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
