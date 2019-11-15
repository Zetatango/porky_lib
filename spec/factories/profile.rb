# frozen_string_literal: true

require 'factory_bot'
require './spec/models/profile'

FactoryBot.define do
  factory :profile, class: 'Profile' do
    user
  end
end
