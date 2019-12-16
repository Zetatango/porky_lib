# frozen_string_literal: true

require './spec/models/partition_provider'

class Proxy < PorkyLib::ApplicationRecord
  include PorkyLib::HasGuid

  belongs_to :partition_provider, required: true

  has_guid 'up'
  validates_with PorkyLib::StringValidator, fields: %i[guid]
end
