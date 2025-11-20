class LineItemsController < ApplicationController
  before_action :set_check, only: [:show, :edit, :update]
  before_action :set_line_item

  def show
    render partial: "line_items/line_item", locals: {line_item: @line_item, check: @check}
  end

  def edit
    render partial: "line_items/form", locals: {line_item: @line_item, check: @check}
  end

  def update
    if @line_item.update(line_item_params)
      render partial: "line_items/line_item", locals: {line_item: @line_item, check: @check}
    else
      render partial: "line_items/form", locals: {line_item: @line_item, check: @check}, status: :unprocessable_entity
    end
  end

  def toggle_participant
    participant = Participant.find(params[:participant_id])

    line_item_participant = @line_item.line_item_participants.find_by(participant: participant)

    if line_item_participant
      line_item_participant.destroy
    else
      @line_item.line_item_participants.create!(participant: participant)
    end

    head :ok
  end

  private

  def set_check
    @check = Check.find(params[:check_id])
  end

  def set_line_item
    @line_item = LineItem.find(params[:id])
  end

  def line_item_params
    params.require(:line_item).permit(:description, :unit_price, :quantity, :discount, :discount_description)
  end
end
