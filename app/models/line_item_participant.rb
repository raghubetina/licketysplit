# == Schema Information
#
# Table name: line_item_participants
# Database name: primary
#
#  id             :uuid             not null, primary key
#  shares         :integer          default(1), not null
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
  validates :shares, numericality: {only_integer: true, greater_than_or_equal_to: 1}
  validate :participant_belongs_to_same_check

  # Equivalent to broadcasts_refreshes_to, but guards the target: during a
  # cascade destroy (check -> line items -> line_item_participants) the parent
  # line item is already gone by after_commit, so line_item is nil and the
  # whole check is being torn down anyway — nothing to refresh.
  after_commit :broadcast_check_refresh

  private

  def broadcast_check_refresh
    target = line_item&.check
    broadcast_refresh_later_to(target) if target
  end

  def participant_belongs_to_same_check
    return unless line_item && participant

    if line_item.check_id != participant.check_id
      errors.add(:participant, "must belong to the same check as the line item")
    end
  end
end
