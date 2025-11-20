class AddonsController < ApplicationController
  before_action :set_line_item
  before_action :set_addon

  def show
    render partial: "addons/addon", locals: {addon: @addon, line_item: @line_item}
  end

  def edit
    render partial: "addons/form", locals: {addon: @addon, line_item: @line_item}
  end

  def update
    if @addon.update(addon_params)
      render partial: "addons/addon", locals: {addon: @addon, line_item: @line_item}
    else
      render partial: "addons/form", locals: {addon: @addon, line_item: @line_item}, status: :unprocessable_entity
    end
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
