# frozen_string_literal: true

require 'factory_bot'
require './spec/models/user'

FactoryBot.define do
  factory :user, class: 'User' do
    partition_guid { SecureRandom.base58(16) }
    encryption_epoch { SecureRandom.base58(16) }
  end
end
