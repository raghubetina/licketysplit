class GlobalDiscountsController < ApplicationController
  before_action :set_check
  before_action :set_global_discount

  def destroy
    @global_discount.destroy
    head :ok
  end

  private

  def set_check
    @check = Check.find(params[:check_id])
  end

  def set_global_discount
    @global_discount = @check.global_discounts.find(params[:id])
  end
end
