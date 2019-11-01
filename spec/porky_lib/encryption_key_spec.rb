# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::EncryptionKey, type: :model do
  it 'has a guid' do
    expect(build(:encryption_key)).to respond_to(:guid)
  end

  it 'has valid guid format' do
    encryption_key = create :encryption_key

    expect(described_class.validation_regexp).to match(encryption_key.guid)
  end

  it 'has a partition_guid' do
    expect(build(:encryption_key)).to respond_to(:partition_guid)
  end

  it 'has a key_epoch' do
    expect(build(:encryption_key)).to respond_to(:key_epoch)
  end

  it 'has a encrypted_data_encryption_key' do
    expect(build(:encryption_key)).to respond_to(:encrypted_data_encryption_key)
  end

  it 'has a version' do
    expect(build(:encryption_key)).to respond_to(:version)
  end

  it 'is invalid without a partition_guid, key_epoch, version or encrypted_data_encryption_key' do
    %i[partition_guid key_epoch encrypted_data_encryption_key version].each do |attribute|
      key = build :encryption_key

      key.send("#{attribute}=", nil)

      expect(key).not_to be_valid
    end
  end

  it 'is invalid with a blank partition_guid, version or encrypted_data_encryption_key' do
    %i[partition_guid encrypted_data_encryption_key version].each do |attribute|
      key = build :encryption_key

      key.send("#{attribute}=", '')

      expect(key).not_to be_valid
    end
  end

  it 'raises an exception when creating a duplicate entry' do
    key = create :encryption_key

    expect { create :encryption_key, partition_guid: key.partition_guid, key_epoch: key.key_epoch }.to raise_exception(ActiveRecord::RecordInvalid)
  end
end
