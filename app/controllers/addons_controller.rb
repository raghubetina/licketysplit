class AddonsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_line_item
  before_action :set_addon

  def show
    render turbo_stream: turbo_stream.replace(
      dom_id(@addon),
      partial: "addons/addon",
      locals: {addon: @addon, line_item: @line_item}
    )
  end

  def edit
    render turbo_stream: turbo_stream.replace(
      dom_id(@addon),
      partial: "addons/form",
      locals: {addon: @addon, line_item: @line_item}
    )
  end

  def update
    if @addon.update(addon_params)
      redirect_to @line_item.check, status: :see_other
    else
      render turbo_stream: turbo_stream.replace(
        dom_id(@addon),
        partial: "addons/form",
        locals: {addon: @addon, line_item: @line_item}
      ), status: :unprocessable_entity
    end
  end

  def destroy
    @addon.destroy
    redirect_to @line_item.check, status: :see_other
  end

  private

  def set_line_item
    @line_item = LineItem.find(params[:line_item_id])
  end

  def set_addon
    @addon = Addon.find(params[:id])
  end

  def addon_params
    params.require(:addon).permit(:description, :unit_price, :quantity, :discount, :discount_description)
  end
end
