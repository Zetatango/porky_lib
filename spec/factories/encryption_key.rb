# frozen_string_literal: true

require 'factory_bot'

FactoryBot.define do
  factory :encryption_key, class: PorkyLib::EncryptionKey do
    partition_guid { SecureRandom.base58(16) }
    key_epoch { Time.now.utc.beginning_of_year }
    encrypted_data_encryption_key { SecureRandom.base58(32) }
    version { PorkyLib::KeyManagementService::KEY_VERSION }
  end
end
