class LineItemsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_check, only: [:create, :show, :edit, :update, :destroy]
  before_action :set_line_item, only: [:show, :edit, :update, :destroy, :toggle_participant]

  def create
    @line_item = @check.line_items.build(line_item_params)
    if @line_item.save
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "new_line_item_form",
            partial: "line_items/new_form",
            locals: {line_item: LineItem.new, check: @check}
          )
        }
        format.html { redirect_to @check }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "new_line_item_form",
            partial: "line_items/new_form",
            locals: {line_item: @line_item, check: @check}
          ), status: :unprocessable_entity
        }
        format.html { redirect_to @check, alert: @line_item.errors.full_messages.join(", ") }
      end
    end
  end

  def show
    render turbo_stream: turbo_stream.replace(
      dom_id(@line_item, :content),
      partial: "line_items/line_item_content",
      locals: {line_item: @line_item, check: @check}
    )
  end

  def edit
    render turbo_stream: turbo_stream.replace(
      dom_id(@line_item, :content),
      partial: "line_items/form",
      locals: {line_item: @line_item, check: @check}
    )
  end

  def update
    if @line_item.update(line_item_params)
      render turbo_stream: turbo_stream.replace(
        dom_id(@line_item, :content),
        partial: "line_items/line_item_content",
        locals: {line_item: @line_item, check: @check}
      )
    else
      render turbo_stream: turbo_stream.replace(
        dom_id(@line_item, :content),
        partial: "line_items/form",
        locals: {line_item: @line_item, check: @check}
      ), status: :unprocessable_entity
    end
  end

  def destroy
    @line_item.destroy
    head :ok
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
