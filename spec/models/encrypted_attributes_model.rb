# frozen_string_literal: true

class EncryptedAttributesModel < PorkyLib::ApplicationRecord
  include PorkyLib::HasGuid

  has_guid 'eam'

  validates_with PorkyLib::StringValidator, fields: %i[guid]

  def generate_partition_guid
    self.partition_guid = partition_guid.presence || generate_guid
  end

  def generate_encryption_epoch
    return encryption_epoch if encryption_epoch.present?

    self.encryption_epoch = PorkyLib::KeyManagementService.encryption_key_epoch(Time.now)
  end

  def provider_partition_guid
    raise ActiveRecord::RecordInvalid unless partition_guid.present?

    partition_guid
  end

  def provider_encryption_epoch
    raise ActiveRecord::RecordInvalid unless encryption_epoch.present?

    encryption_epoch
  end
end
