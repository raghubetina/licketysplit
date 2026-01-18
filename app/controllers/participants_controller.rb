class ParticipantsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_check
  before_action :set_participant, only: [:show, :edit, :update, :destroy]

  def create
    @participant = @check.participants.build(participant_params)
    if @participant.save
      redirect_to @check, status: :see_other
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
      redirect_to @check, status: :see_other
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
    redirect_to @check, status: :see_other
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
