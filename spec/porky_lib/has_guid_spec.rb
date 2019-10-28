# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::HasGuid do
  let(:encryption_key) { create :encryption_key }

  it 'duplicated encryption_key have no guid but get one when they are saved' do
    duplicate = encryption_key.dup
    expect(duplicate.guid).to be_nil
    expect(duplicate.id).to be_nil
    duplicate.partition_guid = duplicate.partition_guid + 'a'
    duplicate.save!
    expect(duplicate.guid).to start_with 'dek'
  end

  it '#to_param returns the guid' do
    expect(encryption_key.to_param).to equal encryption_key.guid
  end

  it 'blank guid on create generates a guid' do
    duplicate = encryption_key.dup
    duplicate.guid = ''
    duplicate.partition_guid = duplicate.partition_guid + 'a'
    duplicate.save!
    expect(duplicate.guid).to start_with 'dek'

    duplicate = encryption_key.dup
    duplicate.guid = nil
    duplicate.partition_guid = duplicate.partition_guid + 'b'
    duplicate.save!
    expect(duplicate.guid).to start_with 'dek'
  end

  it 'prefix is globally unique' do
    expect do
      # rubocop:disable RSpec/LeakyConstantDeclaration
      class OtherEncryptionKeyClass < PorkyLib::ApplicationRecord
        include PorkyLib::HasGuid
        has_guid 'dek'
      end
      # rubocop:enable RSpec/LeakyConstantDeclaration
    end.to raise_error ArgumentError
  end

  it 'guid cannot be changed' do
    expect do
      encryption_key.guid = "dek_#{SecureRandom.base58(16)}"
      encryption_key.save!
    end.to raise_error ActiveRecord::RecordInvalid
  end
end
