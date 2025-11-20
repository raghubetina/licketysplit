module ChecksHelper
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
