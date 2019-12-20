# frozen_string_literal: true

class PartitionProvider < PorkyLib::ApplicationRecord
  include PorkyLib::HasGuid
  include PorkyLib::PartitionProvider

  has_guid 'pp'

  validates_with PorkyLib::StringValidator, fields: %i[guid]

  def provider_partition_guid
    generate_guid
  end

  def provider_encryption_epoch
    PorkyLib::KeyManagementService.encryption_key_epoch(Time.now)
  end
end
