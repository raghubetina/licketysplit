module ChecksHelper
  COMMON_CURRENCY_CODES = %w[
    USD EUR GBP CAD AUD JPY CNY INR MXN BRL
    CHF KRW SGD HKD TWD THB PHP VND IDR MYR
    ZAR AED SAR NZD SEK NOK DKK PLN CZK HUF
    ILS TRY RUB EGP PKR BDT NGN KES COP CLP ARS PEN
  ].freeze

  def currency_options_for_select
    COMMON_CURRENCY_CODES.filter_map do |code|
      currency = Money::Currency.find(code)
      next unless currency

      ["#{currency.iso_code} - #{currency.name}", currency.iso_code]
    end
  end

  def qr_code_svg(url, level: :h)
    qrcode = RQRCode::QRCode.new(url, level: level)
    qrcode.as_svg(
      viewbox: true,
      use_path: true,
      svg_attributes: {
        class: "qr-code w-100"
      }
    ).html_safe
  end

  def check_status_color(status)
    case status
    when "draft"
      "secondary"
    when "reviewing"
      "warning"
    when "finalized"
      "success"
    else
      "light"
    end
  end

  def format_currency(amount, symbol = "$")
    padding = symbol.end_with?(".") ? " " : ""
    "#{symbol}#{padding}#{number_with_precision(amount || 0, precision: 2)}"
  end
end
