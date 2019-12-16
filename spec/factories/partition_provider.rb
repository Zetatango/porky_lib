# frozen_string_literal: true

require 'factory_bot'
require './spec/models/partition_provider'

FactoryBot.define do
  factory :partition_provider, class: 'PartitionProvider'
end
