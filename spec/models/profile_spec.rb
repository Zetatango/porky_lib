# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Profile, type: :model do
  let(:user) { create :user }
  let(:profile) { create :profile, user: user }

  it 'requires a user' do
    expect { described_class.create! }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'can be created with a user' do
    expect { described_class.create!(user: user) }.not_to raise_error
  end

  it 'has a guid' do
    expect(described_class.create!(user: user)).to respond_to(:guid)
  end

  it 'has valid guid format' do
    expect(described_class.validation_regexp).to match(profile.guid)
  end

  describe '#provider_partition_guid' do
    it 'returns the user partition guid as the provider partition guid' do
      expect(profile.provider_partition_guid).to eq(user.partition_guid)
    end

    it 'raises an exception when user is nil' do
      profile = build :profile, user: nil

      expect { profile.provider_partition_guid }.to raise_exception(ActiveRecord::RecordInvalid)
    end

    it 'raises an exception when user partition_guid is nil' do
      profile = build :profile, user: build(:user, partition_guid: nil)

      expect { profile.provider_partition_guid }.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end

  describe '#provider_encryption_epoch' do
    it 'returns the user encryption epoch as the provider encryption guid' do
      expect(profile.provider_encryption_epoch).to eq(user.encryption_epoch)
    end

    it 'raises an exception when user is nil' do
      profile = build :profile, user: nil

      expect { profile.provider_encryption_epoch }.to raise_exception(ActiveRecord::RecordInvalid)
    end

    it 'raises an exception when user encryption_epoch is nil' do
      profile = build :profile, user: build(:user, encryption_epoch: nil)

      expect { profile.provider_encryption_epoch }.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end
end
