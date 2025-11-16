# == Schema Information
#
# Table name: participants
# Database name: primary
#
#  id             :uuid             not null, primary key
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
  # Associations
  belongs_to :check
  has_many :line_item_participants, dependent: :destroy
  has_many :line_items, through: :line_item_participants
  has_one :treat, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: {scope: :check_id, message: "already exists for this check"}
  validates :payment_status, inclusion: {in: %w[unpaid paid]}

  # Enums
  enum :payment_status, {unpaid: "unpaid", paid: "paid"}

  # Scopes
  scope :treated, -> { joins(:treat) }
  scope :not_treated, -> { where.missing(:treat) }

  # Instance methods
  def amount_owed
    check.amount_owed_by(self)
  end

  def is_being_treated?
    treat.present?
  end

  def mark_as_paid!
    update!(payment_status: "paid")
  end

  def mark_as_unpaid!
    update!(payment_status: "unpaid")
  end
end
