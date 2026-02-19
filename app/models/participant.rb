# == Schema Information
#
# Table name: participants
# Database name: primary
#
#  id             :uuid             not null, primary key
#  being_treated  :boolean          default(FALSE), not null
#  name           :string           not null
#  payment_status :string           default("unpaid")
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  check_id       :uuid             not null
#
# Indexes
#
#  index_participants_on_check_id           (check_id)
#  index_participants_on_check_id_and_name  (check_id,name) UNIQUE
#  index_participants_on_payment_status     (payment_status)
#
# Foreign Keys
#
#  fk_rails_...  (check_id => checks.id)
#
class Participant < ApplicationRecord
  auto_strip_attributes :name, squish: true

  belongs_to :check, counter_cache: true
  has_many :line_item_participants, dependent: :destroy
  has_many :line_items, through: :line_item_participants

  validates :name, presence: true
  validates :name, uniqueness: {scope: :check_id, message: "already exists for this check"}

  enum :payment_status, {unpaid: "unpaid", paid: "paid"}

  broadcasts_refreshes_to :check

  scope :treated, -> { where(being_treated: true) }
  scope :not_treated, -> { where(being_treated: false) }

  def self.parse_names(input)
    separator = if input.include?(",")
      ","
    elsif input.include?("\n")
      /\r?\n/
    elsif input.include?(".")
      "."
    else
      /\s+/
    end
    input.split(separator).map { |name| name.squish }.compact_blank
  end

  def amount_owed
    check.amount_owed_by(self)
  end

  def is_being_treated?
    being_treated?
  end

  def mark_as_paid!
    update!(payment_status: "paid")
  end

  def mark_as_unpaid!
    update!(payment_status: "unpaid")
  end
end
