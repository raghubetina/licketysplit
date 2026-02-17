class ChecksController < ApplicationController
  before_action :set_check, only: [:show, :edit, :update, :destroy, :toggle_zero_items, :update_currency]

  def index
    @check = Check.new
    @recent_checks = load_recent_checks
    @all_checks = Check.order(created_at: :desc) if session[:show_all_checks]
  end

  def show
    track_visited_check(@check.id)
    @show_zero_items = cookies[:show_zero_items] == "true"
    @line_items = @check.line_items.includes(:addons, :participants).order(:position)
    @global_fees = @check.global_fees
    @global_discounts = @check.global_discounts
    @participants = @check.participants.order(:name)
  end

  def toggle_zero_items
    if cookies[:show_zero_items] == "true"
      cookies.delete(:show_zero_items)
    else
      cookies[:show_zero_items] = {value: "true", expires: 1.year.from_now}
    end
    redirect_to @check
  end

  def update_currency
    currency_code = params[:currency]
    currency = Money::Currency.find(currency_code)

    if currency
      @check.update(currency: currency_code, currency_symbol: currency.symbol)
    end

    redirect_to @check
  end

  def new
    redirect_to checks_path
  end

  def backdoor
    session[:show_all_checks] = true
    redirect_to root_path
  end

  def create
    if params[:receipt_images].blank?
      @check = Check.new
      @check.errors.add(:receipt_images, "are required")
      @recent_checks = load_recent_checks
      return render :index, status: :unprocessable_entity
    end

    @check = Check.new(status: "parsing")
    @check.receipt_images.attach(params[:receipt_images])

    if params[:participant_names].present?
      names = Participant.parse_names(params[:participant_names])
      names.each { |name| @check.participants.build(name: name) }
    end

    if @check.save
      ParseReceiptJob.perform_later(@check)
      redirect_to @check
    else
      @recent_checks = load_recent_checks
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @check.update(check_params)
      redirect_to @check, notice: "Check was successfully updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @check.destroy
    redirect_to checks_url, notice: "Check was successfully deleted."
  end

  private

  def set_check
    @check = Check.find(params[:id])
  end

  def track_visited_check(check_id)
    visited_ids = JSON.parse(cookies[:visited_checks] || "[]")
    visited_ids.delete(check_id.to_s)
    visited_ids.unshift(check_id.to_s)
    visited_ids = visited_ids.first(20)
    cookies[:visited_checks] = {value: visited_ids.to_json, expires: 1.year.from_now}
  end

  def load_recent_checks
    visited_ids = JSON.parse(cookies[:visited_checks] || "[]")
    return [] if visited_ids.empty?

    checks_by_id = Check.where(id: visited_ids).index_by { |c| c.id.to_s }
    visited_ids.filter_map { |id| checks_by_id[id] }
  end

  def check_params
    params.require(:check).permit(
      :restaurant_name, :restaurant_address, :restaurant_phone_number,
      :billed_on, :grand_total, :currency, :status,
      line_items_attributes: [:id, :description, :quantity, :unit_price,
        :total_price, :discount, :discount_description, :_destroy, participant_ids: []],
      global_fees_attributes: [:id, :description, :amount, :_destroy],
      global_discounts_attributes: [:id, :description, :amount, :_destroy],
      participants_attributes: [:id, :name, :payment_status, :_destroy]
    )
  end
end
