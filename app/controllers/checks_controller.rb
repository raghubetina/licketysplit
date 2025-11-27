class ChecksController < ApplicationController
  before_action :set_check, only: [:show, :edit, :update, :destroy, :toggle_zero_items]

  def index
    @check = Check.new
    @recent_checks = load_recent_checks
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

  def new
    redirect_to checks_path
  end

  def create
    if params[:receipt_image].blank?
      @check = Check.new
      @check.errors.add(:receipt_image, "is required")
      @recent_checks = load_recent_checks
      return render :index, status: :unprocessable_entity
    end

    parser = ReceiptParser.new(params[:receipt_image].tempfile.path)
    parsed_data = parser.parse

    @check = Check.new(parsed_data)
    @check.receipt_image.attach(params[:receipt_image])

    if params[:participant_names].present?
      names = params[:participant_names].split(",").map(&:strip).compact_blank
      names.each do |name|
        @check.participants.build(name: name)
      end
    end

    if @check.save
      redirect_to @check, notice: "Check created! Now assign items to participants."
    else
      @recent_checks = load_recent_checks
      render :index, status: :unprocessable_entity
    end
  rescue => e
    @check = Check.new
    @check.errors.add(:base, "Failed to parse receipt: #{e.message}")
    @recent_checks = load_recent_checks
    render :index, status: :unprocessable_entity
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
      :billed_on, :grand_total, :currency, :status, :receipt_image,
      line_items_attributes: [:id, :description, :quantity, :unit_price,
        :total_price, :discount, :discount_description, :_destroy, participant_ids: []],
      global_fees_attributes: [:id, :description, :amount, :_destroy],
      global_discounts_attributes: [:id, :description, :amount, :_destroy],
      participants_attributes: [:id, :name, :payment_status, :_destroy]
    )
  end
end
