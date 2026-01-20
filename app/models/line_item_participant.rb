# == Schema Information
#
# Table name: line_item_participants
# Database name: primary
#
#  id             :uuid             not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  line_item_id   :uuid             not null
#  participant_id :uuid             not null
#
# Indexes
#
#  index_line_item_participants_on_line_item_id    (line_item_id)
#  index_line_item_participants_on_participant_id  (participant_id)
#  index_line_item_participants_unique             (line_item_id,participant_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (line_item_id => line_items.id)
#  fk_rails_...  (participant_id => participants.id)
#
class LineItemParticipant < ApplicationRecord
  belongs_to :line_item, counter_cache: :participants_count
  belongs_to :participant

  validates :participant_id, uniqueness: {
    scope: :line_item_id,
    message: "is already associated with this line item"
  }
  validate :participant_belongs_to_same_check

  broadcasts_refreshes_to ->(lip) { lip.line_item.check }

  private

  def participant_belongs_to_same_check
    return unless line_item && participant

    if line_item.check_id != participant.check_id
      errors.add(:participant, "must belong to the same check as the line item")
    end
  end
end
