# frozen_string_literal: true

require './spec/models/partition_provider'

class Proxy < PorkyLib::ApplicationRecord
  include PorkyLib::HasGuid
  include PorkyLib::PartitionProvider

  partition_provider_guid :partition_provider_guid, PartitionProvider

  has_guid 'p'
  validates_with PorkyLib::StringValidator, fields: %i[guid]
end
