class ParticipantsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_check
  before_action :set_participant, only: [:show, :edit, :update, :destroy, :toggle_treated, :toggle_paid]

  def create
    @participant = @check.participants.build(participant_params)
    if @participant.save
      redirect_to @check, status: :see_other
    else
      render turbo_stream: turbo_stream.replace(
        "new_participant_form",
        partial: "participants/new_form",
        locals: {participant: @participant, check: @check}
      ), status: :unprocessable_content
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
      ), status: :unprocessable_content
    end
  end

  def destroy
    @participant.destroy
    redirect_to @check, status: :see_other
  end

  def toggle_treated
    turning_on = !@participant.being_treated?

    # Someone has to pay: refuse to treat the last remaining payer, which would
    # otherwise zero out everyone's share and make the whole check vanish.
    if turning_on && @check.non_treated_count <= 1
      return redirect_to @check, alert: "At least one person has to be paying.", status: :see_other
    end

    if @participant.update(being_treated: turning_on)
      redirect_to @check, status: :see_other
    else
      redirect_to @check, alert: @participant.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def toggle_paid
    if @participant.paid?
      @participant.mark_as_unpaid!
    else
      @participant.mark_as_paid!
    end
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
    params.require(:participant).permit(:name, :being_treated)
  end
end
