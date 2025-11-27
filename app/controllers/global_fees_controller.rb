class GlobalFeesController < ApplicationController
  before_action :set_check
  before_action :set_global_fee

  def destroy
    @global_fee.destroy
    head :ok
  end

  private

  def set_check
    @check = Check.find(params[:check_id])
  end

  def set_global_fee
    @global_fee = @check.global_fees.find(params[:id])
  end
end
