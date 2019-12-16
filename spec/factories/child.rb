# frozen_string_literal: true

require 'factory_bot'
require './spec/models/child'

FactoryBot.define do
  factory :child, class: 'Child' do
    association :proxy
  end
end
