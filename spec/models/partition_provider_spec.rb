# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PartitionProvider do
  let(:partition_provider) { create :partition_provider }

  it 'has a guid' do
    expect(partition_provider).to respond_to(:guid)
  end

  it 'has valid guid format' do
    expect(described_class.validation_regexp).to match(partition_provider.guid)
  end

  describe '#provider_partition_guid' do
    it 'returns the user partition guid as the provider partition guid' do
      expect(partition_provider.provider_partition_guid).to eq(partition_provider.guid)
    end
  end

  describe '#provider_encryption_epoch' do
    it 'returns the user encryption epoch as the provider encryption guid' do
      expect(partition_provider.provider_encryption_epoch).to eq(PorkyLib::KeyManagementService.encryption_key_epoch(Time.now))
    end
  end
end
