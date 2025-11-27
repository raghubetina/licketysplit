class GlobalFeesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_check
  before_action :set_global_fee, only: [:show, :edit, :update, :destroy]

  def create
    @global_fee = @check.global_fees.build(global_fee_params)
    if @global_fee.save
      render turbo_stream: turbo_stream.replace(
        "new_global_fee_form",
        partial: "global_fees/new_form",
        locals: {global_fee: GlobalFee.new, check: @check}
      )
    else
      render turbo_stream: turbo_stream.replace(
        "new_global_fee_form",
        partial: "global_fees/new_form",
        locals: {global_fee: @global_fee, check: @check}
      ), status: :unprocessable_entity
    end
  end

  def show
    render turbo_stream: turbo_stream.replace(
      dom_id(@global_fee),
      partial: "global_fees/global_fee",
      locals: {global_fee: @global_fee, check: @check}
    )
  end

  def edit
    render turbo_stream: turbo_stream.replace(
      dom_id(@global_fee),
      partial: "global_fees/form",
      locals: {global_fee: @global_fee, check: @check}
    )
  end

  def update
    if @global_fee.update(global_fee_params)
      render turbo_stream: turbo_stream.replace(
        dom_id(@global_fee),
        partial: "global_fees/global_fee",
        locals: {global_fee: @global_fee, check: @check}
      )
    else
      render turbo_stream: turbo_stream.replace(
        dom_id(@global_fee),
        partial: "global_fees/form",
        locals: {global_fee: @global_fee, check: @check}
      ), status: :unprocessable_entity
    end
  end

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

  def global_fee_params
    params.require(:global_fee).permit(:description, :amount)
  end
end
