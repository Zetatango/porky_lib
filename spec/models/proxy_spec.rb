# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Proxy, type: :model do
  let(:partition_provider) { create :partition_provider }
  let(:proxy) { create :proxy, partition_provider_guid: partition_provider.guid }

  it 'requires a partition_provider_guid' do
    expect { described_class.create! }.to raise_exception(ActiveRecord::NotNullViolation)
  end

  it 'can be created with a partition_provider_guid' do
    expect { described_class.create!(partition_provider_guid: partition_provider.guid) }.not_to raise_error
  end

  it 'has a guid' do
    expect(described_class.create!(partition_provider_guid: partition_provider.guid)).to respond_to(:guid)
  end

  it 'has valid guid format' do
    expect(described_class.validation_regexp).to match(proxy.guid)
  end
end
