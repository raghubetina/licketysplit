class LineItemsController < ApplicationController
  before_action :set_line_item

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

  def set_line_item
    @line_item = LineItem.find(params[:id])
  end
end
