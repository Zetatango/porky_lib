# frozen_string_literal: true

module PorkyLib::HasEncryptedAttributes
  extend ActiveSupport::Concern

  included do
    before_create :generate_partition_guid, :generate_encryption_epoch

    validate :ensure_encryption_info_does_not_change
  end

  def generate_partition_guid
    raise NoMethodError
  end

  def generate_encryption_epoch
    raise NoMethodError
  end

  private

  def ensure_encryption_info_does_not_change
    return if new_record?

    errors.add(:partition_guid, 'cannot be changed for persisted records') if partition_guid_changed?
    errors.add(:encryption_epoch, 'cannot be changed for persisted records') if encryption_epoch_changed?
  end
end
