# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Child, type: :model do
  let(:partition_provider) { create :partition_provider }
  let(:proxy) { create :proxy, partition_provider: partition_provider }
  let(:child) { create :child, proxy: proxy }

  it 'requires a proxy' do
    expect { described_class.create! }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'can be created with a proxy' do
    expect { described_class.create!(proxy: proxy) }.not_to raise_error
  end

  it 'has a guid' do
    expect(described_class.create!(proxy: proxy)).to respond_to(:guid)
  end

  it 'has valid guid format' do
    expect(described_class.validation_regexp).to match(child.guid)
  end

  it 'has value as an encrypted attribute' do
    expect(child.encrypted_attributes.keys).to include(:value)
  end

  describe '#provider_partition_guid' do
    it 'returns the partition_provider partition guid as the provider partition guid' do
      expect(child.provider_partition_guid).to eq(partition_provider.partition_guid)
    end

    it 'raises an exception when proxy is nil' do
      child = build :child, proxy: nil

      expect { child.provider_partition_guid }.to raise_exception(NoMethodError)
    end

    it 'raises an exception when proxy partition_guid is nil' do
      child = build :child, proxy: build(:proxy, partition_provider: build(:partition_provider, partition_guid: nil))

      expect { child.provider_partition_guid }.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end

  describe '#provider_encryption_epoch' do
    it 'returns the partition_provider encryption epoch as the provider encryption guid' do
      expect(child.provider_encryption_epoch).to eq(partition_provider.encryption_epoch)
    end

    it 'raises an exception when proxy is nil' do
      child = build :child, proxy: nil

      expect { child.provider_encryption_epoch }.to raise_exception(NoMethodError)
    end

    it 'raises an exception when proxy encryption_epoch is nil' do
      child = build :child, proxy: build(:proxy, partition_provider: build(:partition_provider, encryption_epoch: nil))

      expect { child.provider_encryption_epoch }.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end
end
