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
    all_participant_ids = check.participant_ids
    current_participant_ids = @line_item.participant_ids

    if current_participant_ids.sort == all_participant_ids.sort
      @line_item.line_item_participants.delete_all
    else
      missing_ids = all_participant_ids - current_participant_ids
      records = missing_ids.map { |pid| {line_item_id: @line_item.id, participant_id: pid} }
      LineItemParticipant.insert_all(records) if records.any?
    end

    LineItem.reset_counters(@line_item.id, :line_item_participants)
    @line_item.touch
    Turbo::StreamsChannel.broadcast_refresh_later_to(check)

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
