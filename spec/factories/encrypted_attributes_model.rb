# frozen_string_literal: true

require 'factory_bot'
require './spec/models/encrypted_attributes_model'

FactoryBot.define do
  factory :encrypted_attributes_model, class: EncryptedAttributesModel do
    partition_guid { SecureRandom.base58(16) }
    encryption_epoch { SecureRandom.base58(16) }
  end
end
