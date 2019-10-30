# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EncryptedAttributesModel do
  let(:encrypted_attributes_model) { create :encrypted_attributes_model }

  describe '#provider_partition_guid' do
    it 'returns the user partition guid as the provider partition guid' do
      expect(encrypted_attributes_model.provider_partition_guid).to eq(encrypted_attributes_model.partition_guid)
    end

    it 'raises an exception if partition_guid is nil' do
      encrypted_attributes_model = build :encrypted_attributes_model, partition_guid: nil

      expect do
        encrypted_attributes_model.provider_partition_guid
      end.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end

  describe '#provider_encryption_epoch' do
    it 'returns the user encryption epoch as the provider encryption guid' do
      expect(encrypted_attributes_model.provider_encryption_epoch).to eq(encrypted_attributes_model.encryption_epoch)
    end

    it 'raises an exception if encryption_epoch is nil' do
      encrypted_attributes_model = build :encrypted_attributes_model, encryption_epoch: nil

      expect do
        encrypted_attributes_model.provider_encryption_epoch
      end.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end
end
