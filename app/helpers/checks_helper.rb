module ChecksHelper
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
