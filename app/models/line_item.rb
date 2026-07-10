# == Schema Information
#
# Table name: line_items
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  description          :text             not null
#  discount             :decimal(10, 2)   default(0.0)
#  discount_description :string
#  participants_count   :integer          default(0)
#  position             :integer          default(0)
#  quantity             :integer          default(1)
#  total_price          :decimal(10, 2)
#  uneven_split         :boolean          default(FALSE), not null
#  unit_price           :decimal(10, 2)   not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  check_id             :uuid             not null
#
# Indexes
#
#  index_line_items_on_check_id  (check_id)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class LineItem < ApplicationRecord
  include HasWarnings

  belongs_to :check, counter_cache: true
  has_many :line_item_participants, dependent: :destroy
  has_many :participants, through: :line_item_participants
  has_many :addons, dependent: :destroy

  validates :description, presence: true
  validates :unit_price, presence: true, numericality: true
  validates :quantity, presence: true, numericality: {greater_than_or_equal_to: 1}
  validates :discount, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  accepts_nested_attributes_for :addons, allow_destroy: true

  before_validation :set_defaults
  before_save :calculate_total

  broadcasts_refreshes_to :check

  def base_total
    (unit_price * quantity) - discount
  end

  def addons_total
    addons.sum(:total_price)
  end

  def total_with_addons
    base_total + addons_total
  end

  def amount_per_participant
    return 0 if participants_count == 0
    total_with_addons / participants_count
  end

  def total_assigned_shares
    line_item_participants.sum(&:shares)
  end

  def shares_for(participant)
    line_item_participants.detect { |lip| lip.participant_id == participant.id }&.shares || 0
  end

  # Per-(item, participant) amount. In even mode every assignee pays the same
  # slice; in uneven mode each pays for their share count, with addons and the
  # item discount distributed proportionally by share fraction.
  def amount_for(participant)
    shares = shares_for(participant)
    return 0 if shares == 0
    return amount_per_participant unless uneven_split?

    (shares * unit_price) + ((addons_total - discount) * shares / total_assigned_shares)
  end

  # Value of the item nobody has claimed yet. In uneven mode this is the
  # unassigned units; over-assignment clamps to zero.
  def unallocated_total
    if uneven_split?
      assigned = total_assigned_shares
      return total_with_addons if assigned == 0
      (quantity - assigned).clamp(0..) * unit_price
    else
      (participants_count == 0) ? total_with_addons : 0
    end
  end

  # Switch to uneven mode, seeding shares by distributing the quantity across
  # current assignees as evenly as possible (deterministically, by name).
  # Assignees beyond the quantity get dropped since shares must be >= 1.
  def enable_uneven_split!
    transaction do
      assignees = line_item_participants.joins(:participant).order("participants.name").to_a
      if assignees.any?
        base = quantity / assignees.size
        remainder = quantity - (base * assignees.size)
        assignees.each_with_index do |lip, index|
          new_shares = base + ((index < remainder) ? 1 : 0)
          if new_shares.zero?
            lip.destroy
          else
            lip.update!(shares: new_shares)
          end
        end
      end
      update!(uneven_split: true)
    end
  end

  # Collapse back to an even split: anyone holding shares stays assigned.
  def revert_to_even_split!
    transaction do
      line_item_participants.update_all(shares: 1)
      update!(uneven_split: false)
    end
  end

  private

  def set_defaults
    self.quantity ||= 1
    self.discount ||= 0
  end

  def calculate_total
    self.total_price = base_total
  end

  def run_warning_checks
    if unit_price && unit_price < 0
      add_warning(:unit_price, "is negative (#{unit_price}). This might be a comped item that should be recorded as a discount instead.")
    end

    if discount && unit_price && discount > unit_price
      add_warning(:discount, "exceeds the item price. Please verify this is correct.")
    end

    if unit_price && unit_price > 1000
      add_warning(:unit_price, "seems unusually high (#{unit_price}). Please verify this is correct.")
    end

    if uneven_split? && total_assigned_shares > quantity
      add_warning(:quantity, "is #{quantity} but #{total_assigned_shares} shares are assigned. The group is paying for more than the item total.")
    end
  end
end
