# frozen_string_literal: true

require 'porky_lib/validators/string_validator'

class PorkyLib::EncryptionKey < PorkyLib::ApplicationRecord
  include PorkyLib::HasGuid

  has_guid 'dek'

  validates :partition_guid, presence: true, allow_blank: false
  validates :key_epoch, presence: true, allow_blank: false, uniqueness: { scope: :partition_guid }
  validates :encrypted_data_encryption_key, presence: true, allow_blank: false
  validates :version, presence: true, allow_blank: false

  validates_with PorkyLib::StringValidator, fields: %i[guid partition_guid encrypted_data_encryption_key version]
end
