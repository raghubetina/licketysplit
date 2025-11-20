# == Schema Information
#
# Table name: treats
# Database name: primary
#
#  id             :uuid             not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  check_id       :uuid             not null
#  participant_id :uuid             not null
#
# Indexes
#
#  index_treats_on_check_id                     (check_id)
#  index_treats_on_check_id_and_participant_id  (check_id,participant_id) UNIQUE
#  index_treats_on_participant_id               (participant_id)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#  fk_rails_...  (participant_id => participants.id)
#
class Treat < ApplicationRecord
  belongs_to :check
  belongs_to :participant

  validates :participant_id, uniqueness: {
    scope: :check_id,
    message: "is already being treated for this check"
  }
  validate :participant_belongs_to_check

  private

  def participant_belongs_to_check
    return unless check && participant

    unless check.participants.include?(participant)
      errors.add(:participant, "must be a participant in this check")
    end
  end
end
