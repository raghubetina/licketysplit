class ParticipantsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_check
  before_action :set_participant, only: [:show, :edit, :update, :destroy]

  def create
    @participant = @check.participants.build(participant_params)
    if @participant.save
      render turbo_stream: turbo_stream.replace(
        "new_participant_form",
        partial: "participants/new_form",
        locals: {participant: Participant.new, check: @check}
      )
    else
      render turbo_stream: turbo_stream.replace(
        "new_participant_form",
        partial: "participants/new_form",
        locals: {participant: @participant, check: @check}
      ), status: :unprocessable_entity
    end
  end

  def show
    render turbo_stream: turbo_stream.replace(
      dom_id(@participant),
      partial: "participants/participant",
      locals: {participant: @participant, check: @check}
    )
  end

  def edit
    render turbo_stream: turbo_stream.replace(
      dom_id(@participant),
      partial: "participants/form",
      locals: {participant: @participant, check: @check}
    )
  end

  def update
    if @participant.update(participant_params)
      render turbo_stream: turbo_stream.replace(
        dom_id(@participant),
        partial: "participants/participant",
        locals: {participant: @participant, check: @check}
      )
    else
      render turbo_stream: turbo_stream.replace(
        dom_id(@participant),
        partial: "participants/form",
        locals: {participant: @participant, check: @check}
      ), status: :unprocessable_entity
    end
  end

  def destroy
    @participant.destroy
    head :ok
  end

  private

  def set_check
    @check = Check.find(params[:check_id])
  end

  def set_participant
    @participant = @check.participants.find(params[:id])
  end

  def participant_params
    params.require(:participant).permit(:name)
  end
end
