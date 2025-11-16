require "ai-chat"

class ReceiptParser
  attr_reader :image_path, :chat

  def initialize(image_path)
    @image_path = image_path.to_s  # Ensure it's a string, not Pathname
    @chat = AI::Chat.new
  end

  def parse
    configure_chat

    chat.user(
      "Extract all items, fees, and discounts from this receipt. " \
      "Identify the restaurant name, date, and total. " \
      "For each line item, extract the name, quantity, unit price, and total price. " \
      "Identify taxes, tips, and service charges as fees. " \
      "Identify any discounts or promotions.",
      image: image_path
    )

    response = chat.generate![:content]
    transform_to_check_attributes(response)
  rescue StandardError => e
    Rails.logger.error "Receipt parsing failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def configure_chat
    chat.model = "gpt-5.1"  # Latest model for better accuracy
    chat.reasoning_effort = "medium"  # Enable reasoning for complex receipts
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
            properties: {
              name: { type: "string", description: "Restaurant/store name" },
              address: { type: ["string", "null"], description: "Restaurant address if visible" },
              phone: { type: ["string", "null"], description: "Phone number if visible" }
            },
            required: ["name", "address", "phone"],
            additionalProperties: false
          },
          receipt_date: { type: ["string", "null"], description: "Date/time of transaction in ISO format" },
          subtotal: { type: "number", description: "Subtotal before taxes and fees" },
          total: { type: "number", description: "Final total amount" },
          currency: { type: "string", description: "Currency code (USD, EUR, etc.)", default: "USD" },
          line_items: {
            type: "array",
            description: "Individual items on the receipt",
            items: {
              type: "object",
              properties: {
                name: { type: "string", description: "Item name/description" },
                description: {
                  type: ["string", "null"],
                  description: "Additional item details (size, preparation, etc.)"
                },
                quantity: { type: "integer", description: "Quantity ordered", default: 1 },
                unit_price: { type: "number", description: "Price per unit" },
                total_price: { type: "number", description: "Total for this line item" },
                item_discount: {
                  type: ["number", "null"],
                  description: "Discount amount for this specific item (positive number)"
                },
                item_discount_description: {
                  type: ["string", "null"],
                  description: "Description of the item-specific discount"
                },
                modifications: {
                  type: ["array", "null"],
                  description: "Modifications or add-ons for this item",
                  items: {
                    type: "object",
                    properties: {
                      name: { type: "string", description: "Modification/addon name" },
                      quantity: { type: "integer", description: "Quantity of this addon", default: 1 },
                      price_per: { type: ["number", "null"], description: "Price per unit of addon" },
                      total_price: { type: "number", description: "Total cost for this addon" },
                      discount: { type: ["number", "null"], description: "Discount on this addon" },
                      discount_description: { type: ["string", "null"], description: "Description of addon discount" }
                    },
                    required: ["name", "quantity", "price_per", "total_price", "discount", "discount_description"],
                    additionalProperties: false
                  }
                }
              },
              required: ["name", "description", "quantity", "unit_price", "total_price", "item_discount", "item_discount_description", "modifications"],
              additionalProperties: false
            }
          },
          fees: {
            type: "array",
            description: "Taxes, tips, service charges",
            items: {
              type: "object",
              properties: {
                description: { type: "string", description: "Fee description" },
                amount: { type: "number", description: "Fee amount" }
              },
              required: ["description", "amount"],
              additionalProperties: false
            }
          },
          discounts: {
            type: "array",
            description: "Discounts or promotions",
            items: {
              type: "object",
              properties: {
                description: { type: "string", description: "Discount description" },
                amount: { type: "number", description: "Discount amount (positive number)" }
              },
              required: ["description", "amount"],
              additionalProperties: false
            }
          }
        },
        required: ["restaurant", "receipt_date", "subtotal", "total", "currency", "line_items", "fees", "discounts"],
        additionalProperties: false
      }
    }
  end

  def transform_to_check_attributes(parsed_data)
    {
      restaurant_name: parsed_data[:restaurant][:name],
      restaurant_address: parsed_data[:restaurant][:address],
      restaurant_phone_number: parsed_data[:restaurant][:phone],
      receipt_at: parse_date(parsed_data[:receipt_date]),
      total: parsed_data[:total],
      currency: parsed_data[:currency] || "USD",
      status: "reviewing",
      line_items_attributes: transform_line_items(parsed_data[:line_items]),
      fees_attributes: parsed_data[:fees].map { |fee|
        {
          description: fee[:description],
          amount: fee[:amount]
        }
      },
      discounts_attributes: parsed_data[:discounts].map { |discount|
        {
          description: discount[:description],
          amount: discount[:amount]
        }
      }
    }
  end

  def transform_line_items(items)
    items.map do |item|
      line_item = {
        name: item[:name],
        description: item[:description],
        quantity: item[:quantity],
        price: item[:unit_price],
        line_item_total: item[:total_price]
      }

      # Add item-specific discount if present
      if item[:item_discount].present? && item[:item_discount] > 0
        line_item[:discount] = item[:item_discount]
        line_item[:discount_description] = item[:item_discount_description]
      end

      if item[:modifications].present?
        line_item[:addons_attributes] = item[:modifications].map do |mod|
          addon = {
            description: mod[:name],
            quantity: mod[:quantity] || 1,
            price: mod[:total_price]
          }

          # Add price_per if present
          addon[:price_per] = mod[:price_per] if mod[:price_per].present?

          # Add addon discount if present
          if mod[:discount].present? && mod[:discount] > 0
            addon[:discount] = mod[:discount]
            addon[:discount_description] = mod[:discount_description]
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