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

  it 'has a partition_guid' do
    expect(partition_provider).to respond_to(:partition_guid)
  end

  it 'has a encryption_epoch' do
    expect(partition_provider).to respond_to(:encryption_epoch)
  end

  describe '#provider_partition_guid' do
    it 'returns the user partition guid as the provider partition guid' do
      expect(partition_provider.provider_partition_guid).to eq(partition_provider.partition_guid)
    end

    it 'raises an exception if partition_guid is nil' do
      partition_provider = build :partition_provider, partition_guid: nil

      expect do
        partition_provider.provider_partition_guid
      end.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end

  describe '#provider_encryption_epoch' do
    it 'returns the user encryption epoch as the provider encryption guid' do
      expect(partition_provider.provider_encryption_epoch).to eq(partition_provider.encryption_epoch)
    end

    it 'raises an exception if encryption_epoch is nil' do
      partition_provider = build :partition_provider, encryption_epoch: nil

      expect do
        partition_provider.provider_encryption_epoch
      end.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end
end
