module ChecksHelper
  def qr_code_svg(url, size: 100)
    qrcode = RQRCode::QRCode.new(url)
    qrcode.as_svg(
      viewbox: true,
      use_path: true,
      svg_attributes: {
        width: size,
        height: size,
        class: "qr-code"
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

  def format_currency(amount, currency = "USD")
    return "$0.00" if amount.nil?

    case currency
    when "USD"
      "$#{number_with_precision(amount, precision: 2)}"
    when "EUR"
      "€#{number_with_precision(amount, precision: 2)}"
    else
      "#{currency} #{number_with_precision(amount, precision: 2)}"
    end
  end
end
