# frozen_string_literal: true

require 'factory_bot'
require './spec/models/proxy'

FactoryBot.define do
  factory :proxy, class: 'Proxy' do
    association :partition_provider
  end
end
