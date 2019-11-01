# frozen_string_literal: true

require 'spec_helper'

RSpec.describe User do
  let(:user) { create :user }

  it 'has a guid' do
    expect(user).to respond_to(:guid)
  end

  it 'has valid guid format' do
    expect(described_class.validation_regexp).to match(user.guid)
  end

  it 'has a partition_guid' do
    expect(user).to respond_to(:partition_guid)
  end

  it 'has a encryption_epoch' do
    expect(user).to respond_to(:encryption_epoch)
  end

  describe '#provider_partition_guid' do
    it 'returns the user partition guid as the provider partition guid' do
      expect(user.provider_partition_guid).to eq(user.partition_guid)
    end

    it 'raises an exception if partition_guid is nil' do
      user = build :user, partition_guid: nil

      expect do
        user.provider_partition_guid
      end.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end

  describe '#provider_encryption_epoch' do
    it 'returns the user encryption epoch as the provider encryption guid' do
      expect(user.provider_encryption_epoch).to eq(user.encryption_epoch)
    end

    it 'raises an exception if encryption_epoch is nil' do
      user = build :user, encryption_epoch: nil

      expect do
        user.provider_encryption_epoch
      end.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end
end
