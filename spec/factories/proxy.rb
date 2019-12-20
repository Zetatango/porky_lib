# frozen_string_literal: true

require 'factory_bot'
require './spec/models/proxy'

FactoryBot.define do
  factory :proxy, class: 'Proxy' do
    partition_provider_guid { 'mfgklasdmf' }
  end
end
