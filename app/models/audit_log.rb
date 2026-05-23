class AuditLog < ApplicationRecord
  self.inheritance_column = nil # we use 'auditable_type' as polymorphic; no STI

  belongs_to :organization
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true

  validates :action, presence: true

  def self.record!(auditable:, action:, actor:, organization:, changes: {}, ip: nil)
    create!(
      auditable: auditable,
      action: action,
      actor: actor,
      organization: organization,
      changes_data: changes.to_h,
      ip_address: ip
    )
  end
end
