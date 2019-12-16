# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Proxy, type: :model do
  let(:partition_provider) { create :partition_provider }
  let(:proxy) { create :proxy, partition_provider: partition_provider }

  it 'requires a user' do
    expect { described_class.create! }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'can be created with a user' do
    expect { described_class.create!(partition_provider: partition_provider) }.not_to raise_error
  end

  it 'has a guid' do
    expect(described_class.create!(partition_provider: partition_provider)).to respond_to(:guid)
  end

  it 'has valid guid format' do
    expect(described_class.validation_regexp).to match(proxy.guid)
  end
end
