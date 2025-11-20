class ChecksController < ApplicationController
  before_action :set_check, only: [:show, :edit, :update, :destroy]

  def index
    @checks = Check.includes(:line_items, :global_fees, :global_discounts, :participants)
      .order(created_at: :desc)
  end

  def show
    @line_items = @check.line_items.includes(:addons)
    @global_fees = @check.global_fees
    @global_discounts = @check.global_discounts
    @participants = @check.participants.includes(:line_items)
  end

  def new
    @check = Check.new
  end

  def create
    @check = Check.new(check_params)

    if @check.save
      redirect_to @check, notice: "Check was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @check.update(check_params)
      redirect_to @check, notice: "Check was successfully updated."
    else
      render :edit, status: :unprocessable_entity
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

  def check_params
    params.require(:check).permit(
      :restaurant_name, :restaurant_address, :restaurant_phone_number,
      :billed_on, :grand_total, :currency, :status, :receipt_image,
      line_items_attributes: [:id, :description, :quantity, :unit_price,
        :total_price, :discount, :discount_description, :_destroy],
      global_fees_attributes: [:id, :description, :amount, :_destroy],
      global_discounts_attributes: [:id, :description, :amount, :_destroy],
      participants_attributes: [:id, :name, :payment_status, :_destroy]
    )
  end
end
