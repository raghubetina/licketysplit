class LineItemsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_check, only: [:create, :show, :edit, :update, :destroy]
  before_action :set_line_item, only: [:show, :edit, :update, :destroy, :toggle_participant, :toggle_all_participants]

  def create
    @line_item = @check.line_items.build(line_item_params)
    if @line_item.save
      redirect_to @check, status: :see_other
    else
      render turbo_stream: turbo_stream.replace(
        "new_line_item_form",
        partial: "line_items/new_form",
        locals: {line_item: @line_item, check: @check}
      ), status: :unprocessable_entity
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
      redirect_to @check, status: :see_other
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
    redirect_to @check, status: :see_other
  end

  def toggle_participant
    participant = Participant.find(params[:participant_id])

    line_item_participant = @line_item.line_item_participants.find_by(participant: participant)

    if line_item_participant
      line_item_participant.destroy
    else
      @line_item.line_item_participants.create!(participant: participant)
    end

    redirect_to @line_item.check, status: :see_other
  end

  def toggle_all_participants
    check = @line_item.check

    if @line_item.participant_ids.sort == check.participant_ids.sort
      @line_item.line_item_participants.destroy_all
    else
      missing_ids = check.participant_ids - @line_item.participant_ids
      missing_ids.each { |pid| @line_item.line_item_participants.create!(participant_id: pid) }
    end

    redirect_to check, status: :see_other
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
