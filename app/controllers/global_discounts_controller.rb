class GlobalDiscountsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_check
  before_action :set_global_discount, only: [:show, :edit, :update, :destroy]

  def create
    @global_discount = @check.global_discounts.build(global_discount_params)
    if @global_discount.save
      redirect_to @check, status: :see_other
    else
      render turbo_stream: turbo_stream.replace(
        "new_global_discount_form",
        partial: "global_discounts/new_form",
        locals: {global_discount: @global_discount, check: @check}
      ), status: :unprocessable_content
    end
  end

  def show
    render turbo_stream: turbo_stream.replace(
      dom_id(@global_discount),
      partial: "global_discounts/global_discount",
      locals: {global_discount: @global_discount, check: @check}
    )
  end

  def edit
    render turbo_stream: turbo_stream.replace(
      dom_id(@global_discount),
      partial: "global_discounts/form",
      locals: {global_discount: @global_discount, check: @check}
    )
  end

  def update
    if @global_discount.update(global_discount_params)
      redirect_to @check, status: :see_other
    else
      render turbo_stream: turbo_stream.replace(
        dom_id(@global_discount),
        partial: "global_discounts/form",
        locals: {global_discount: @global_discount, check: @check}
      ), status: :unprocessable_content
    end
  end

  def destroy
    @global_discount.destroy
    redirect_to @check, status: :see_other
  end

  private

  def set_check
    @check = Check.find(params[:check_id])
  end

  def set_global_discount
    @global_discount = @check.global_discounts.find(params[:id])
  end

  def global_discount_params
    params.require(:global_discount).permit(:description, :amount)
  end
end
