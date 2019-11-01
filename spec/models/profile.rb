# frozen_string_literal: true

require './spec/models/user'

class Profile < PorkyLib::ApplicationRecord
  include PorkyLib::PartitionProvider
  include PorkyLib::HasGuid

  partition_provider :user

  belongs_to :user, required: true

  has_guid 'prof'
  validates_with PorkyLib::StringValidator, fields: %i[guid]
end
