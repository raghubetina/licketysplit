class LineItemsController < ApplicationController
  before_action :set_line_item

  def toggle_participant
    participant = Participant.find(params[:participant_id])

    if @line_item.participants.include?(participant)
      @line_item.participants.delete(participant)
    else
      @line_item.participants << participant
    end

    # Manually broadcast refresh since association callbacks may not fire
    @line_item.check.broadcast_refresh

    head :ok
  end

  private

  def set_line_item
    @line_item = LineItem.find(params[:id])
  end
end
