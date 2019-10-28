# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::KeyManagementService, type: :request do
  subject(:service) { described_class.new(partition_guid, expires_in, cmk_key_id) }

  let(:partition_guid) { SecureRandom.base58(16) }
  let(:expires_in) { 5.minutes }
  let(:cmk_key_id) { 'alias/zetatango' }

  shared_examples_for '#encryption_key_epoch' do
    it 'returns the correct day' do
      expect(described_class.encryption_key_epoch(date).day).to equal(1)
    end

    it 'returns the correct month' do
      expect(described_class.encryption_key_epoch(date).month).to equal(1)
    end

    it 'returns the correct year' do
      expect(described_class.encryption_key_epoch(date).year).to equal(year)
    end

    it 'returns the correct timezone' do
      expect(described_class.encryption_key_epoch(date).zone).to eq('UTC')
    end
  end

  describe '#encryption_key_epoch' do
    describe 'with current datetime' do
      include_examples '#encryption_key_epoch' do
        let(:date) { Time.now }
        let(:year) { date.year }
      end
    end

    describe 'with random date' do
      include_examples '#encryption_key_epoch' do
        let(:day) { SecureRandom.random_number(28) + 1 }
        let(:month) { SecureRandom.random_number(12) + 1 }
        let(:year) { 1900 + SecureRandom.random_number(150) }

        let(:date) { Time.new(year, month, day, 12, 0) }
      end
    end

    describe "on New Year's Eve" do
      include_examples '#encryption_key_epoch' do
        let(:year) { 1900 + SecureRandom.random_number(150) }

        let(:date) { DateTime.new(year - 1, 12, 31, 22, 0, 0, 'EDT') }
      end
    end
  end

  describe '#new' do
    it 'raises an exception when partition_guid is nil' do
      expect { described_class.new(nil, expires_in, cmk_key_id) }.to raise_exception(PorkyLib::KeyManagementService::InvalidParameterException)
    end

    it 'raises an exception when partition_guid is blank' do
      expect { described_class.new('', expires_in, cmk_key_id) }.to raise_exception(PorkyLib::KeyManagementService::InvalidParameterException)
    end

    it 'raises an exception when expires_in is nil' do
      expect { described_class.new(partition_guid, nil, cmk_key_id) }.to raise_exception(PorkyLib::KeyManagementService::InvalidParameterException)
    end

    it 'raises an exception when expires_in is blank' do
      expect { described_class.new(partition_guid, '', cmk_key_id) }.to raise_exception(PorkyLib::KeyManagementService::InvalidParameterException)
    end

    it 'raises an exception when cmk_key_id is nil' do
      expect { described_class.new(partition_guid, expires_in, nil) }.to raise_exception(PorkyLib::KeyManagementService::InvalidParameterException)
    end

    it 'raises an exception when cmk_key_id is blank' do
      expect { described_class.new(partition_guid, expires_in, '') }.to raise_exception(PorkyLib::KeyManagementService::InvalidParameterException)
    end
  end

  describe '#find_or_create_encryption_key' do
    let(:raw_ciphertext_key) { SecureRandom.base58(16) }
    let(:encrypted_data_encryption_key) { Base64.encode64(raw_ciphertext_key) }
    let(:plaintext_key) { SecureRandom.base58(16) }
    let(:encryption_epoch) { described_class.encryption_key_epoch(Time.now.utc) }

    before do
      allow(PorkyLib::Symmetric.instance).to receive(:generate_data_encryption_key)
        .and_return([plaintext_key, raw_ciphertext_key])
    end

    it 'does not make a call to PorkyLib when a key already exists' do
      create :encryption_key, partition_guid: partition_guid, key_epoch: encryption_epoch

      service.find_or_create_encryption_key(encryption_epoch)

      expect(PorkyLib::Symmetric.instance).not_to have_received(:generate_data_encryption_key)
    end

    it 'does make a call to PorkyLib::Symmetric when a key cannot be found' do
      service.find_or_create_encryption_key(encryption_epoch)

      expect(PorkyLib::Symmetric.instance).to have_received(:generate_data_encryption_key)
    end

    it 'raises an exception when the call to PorkyLib::Symmetric fails' do
      allow(PorkyLib::Symmetric.instance).to receive(:generate_data_encryption_key)
        .and_raise(Aws::Errors::ServiceError.new(nil, ''))

      expect { service.find_or_create_encryption_key(encryption_epoch) }.to raise_exception(PorkyLib::KeyManagementService::KeyGenerationException)
    end

    it 'raises an exception when the call to create an EncryptionKey fails (failure other than RecordInvalid)' do
      allow(PorkyLib::EncryptionKey).to receive(:create!).and_raise(ActiveRecord::ActiveRecordError)

      expect { service.find_or_create_encryption_key(encryption_epoch) }.to raise_exception(PorkyLib::KeyManagementService::KeyCreateException)
    end

    it 'raises an exception when the call to create an EncryptionKey fails (failure on RecordInvalid that is not a uniqueness violation)' do
      allow(PorkyLib::EncryptionKey).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect { service.find_or_create_encryption_key(encryption_epoch) }.to raise_exception(PorkyLib::KeyManagementService::KeyCreateException)
    end

    it 'retries find on failure to create with uniqueness violation (RecordInvalid on a uniqueness violation)' do
      encryption_key = build :encryption_key
      encryption_key.errors.add(:partition_guid, :invalid, message: 'Partition guid has already been taken')
      encryption_key.errors.add(:key_epoch, :invalid, message: 'Key epoch has already been taken')

      allow(PorkyLib::EncryptionKey).to receive(:find_by)
      allow(PorkyLib::EncryptionKey).to receive(:create!).and_raise(ActiveRecord::RecordInvalid, encryption_key)

      service.find_or_create_encryption_key(encryption_epoch)

      expect(PorkyLib::EncryptionKey).to have_received(:find_by).twice
    end

    it 'retries find on failure to create with uniqueness violation (RecordNotUnique)' do
      allow(PorkyLib::EncryptionKey).to receive(:find_by)
      allow(PorkyLib::EncryptionKey).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

      service.find_or_create_encryption_key(encryption_epoch)

      expect(PorkyLib::EncryptionKey).to have_received(:find_by).twice
    end

    it 'does not raise an exception when caching the plaintext encryption key fails' do
      allow(Rails.cache).to receive(:write).and_raise(Redis::TimeoutError)

      expect { service.find_or_create_encryption_key(encryption_epoch) }.not_to raise_exception
    end

    it 'returns an EncryptionKey on redis write failure' do
      allow(Rails.cache).to receive(:write).and_raise(Redis::TimeoutError)

      expect(service.find_or_create_encryption_key(encryption_epoch)).to be_a(PorkyLib::EncryptionKey)
    end

    it 'returns an EncryptionKey with the correct key_epoch on successful find' do
      create :encryption_key, partition_guid: partition_guid, key_epoch: encryption_epoch

      key = service.find_or_create_encryption_key(encryption_epoch)

      expect(key.key_epoch).to eq(encryption_epoch)
    end

    it 'creates a new key when one does not exist' do
      expect do
        service.find_or_create_encryption_key(encryption_epoch)
      end.to change(PorkyLib::EncryptionKey, :count).by(1)
    end

    it 'creates a new key with the correct key_epoch' do
      key = service.find_or_create_encryption_key(encryption_epoch)

      expect(key.key_epoch).to eq(encryption_epoch)
    end

    it 'does not create a new key when one already exists' do
      create :encryption_key, partition_guid: partition_guid, key_epoch: described_class.encryption_key_epoch(Time.now.utc)

      expect do
        service.find_or_create_encryption_key(encryption_epoch)
      end.not_to change(PorkyLib::EncryptionKey, :count)
    end

    it 'makes a call to the cache to store the plaintext key when the key is created' do
      allow(Rails.cache).to receive(:write)

      service.find_or_create_encryption_key(encryption_epoch)

      expect(Rails.cache).to have_received(:write)
    end

    it 'returns the correct guid' do
      key = create :encryption_key, partition_guid: partition_guid, key_epoch: described_class.encryption_key_epoch(Time.now.utc)

      expect(service.find_or_create_encryption_key(encryption_epoch).guid).to eq(key.guid)
    end

    it 'returns the correct encrypted_data_encryption_key' do
      expect(service.find_or_create_encryption_key(encryption_epoch).encrypted_data_encryption_key).to eq(encrypted_data_encryption_key)
    end

    it 'returns the correct version' do
      expect(service.find_or_create_encryption_key(encryption_epoch).version).to eq(PorkyLib::KeyManagementService::KEY_VERSION)
    end
  end

  describe '#retrieve_plaintext_key' do
    let(:raw_ciphertext_key) { SecureRandom.base58(16) }
    let(:encrypted_data_encryption_key) { Base64.encode64(raw_ciphertext_key) }
    let(:encryption_key) { create :encryption_key, encrypted_data_encryption_key: encrypted_data_encryption_key }
    let(:plaintext_key) { SecureRandom.base58(16) }

    before do
      allow(PorkyLib::Symmetric.instance).to receive(:decrypt_data_encryption_key).with(raw_ciphertext_key)
                                                                                  .and_return(plaintext_key)
    end

    it 'raises an exception when encryption_key is nil' do
      expect { service.retrieve_plaintext_key(nil) }.to raise_exception(PorkyLib::KeyManagementService::InvalidParameterException)
    end

    it 'attempts to read the plaintext key from cache' do
      allow(Rails.cache).to receive(:read)

      service.retrieve_plaintext_key(encryption_key)

      expect(Rails.cache).to have_received(:read)
    end

    it 'does not raise an exception on cache read failure' do
      allow(Rails.cache).to receive(:read).and_raise(Redis::TimeoutError)

      expect { service.retrieve_plaintext_key(encryption_key) }.not_to raise_exception
    end

    it 'returns the correct plaintext key on cache read failure' do
      allow(Rails.cache).to receive(:read).and_raise(Redis::TimeoutError)

      expect(service.retrieve_plaintext_key(encryption_key)).to eq(plaintext_key)
    end

    it 'does not make a call to PorkyLib::Symmetric on cache hit' do
      allow(Rails.cache).to receive(:read).and_return(plaintext_key)

      service.retrieve_plaintext_key(encryption_key)

      expect(PorkyLib::Symmetric.instance).not_to have_received(:decrypt_data_encryption_key)
    end

    it 'does make a call to PorkyLib::Symmetric on cache miss' do
      allow(Rails.cache).to receive(:read).and_return(nil)

      service.retrieve_plaintext_key(encryption_key)

      expect(PorkyLib::Symmetric.instance).to have_received(:decrypt_data_encryption_key).with(raw_ciphertext_key)
    end

    it 'raises an exception when the call to PorkyLib::Symmetric fails' do
      allow(PorkyLib::Symmetric.instance).to receive(:decrypt_data_encryption_key).with(raw_ciphertext_key)
                                                                                  .and_raise(Aws::Errors::ServiceError.new(nil, ''))

      expect { service.retrieve_plaintext_key(encryption_key) }.to raise_exception(PorkyLib::KeyManagementService::KeyRetrieveException)
    end

    it 'does not raise an exception on cache write failure' do
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write).and_raise(Redis::TimeoutError)

      expect { service.retrieve_plaintext_key(encryption_key) }.not_to raise_exception
    end

    it 'returns the correct plaintext key on cache write failure' do
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write).and_raise(Redis::TimeoutError)

      expect(service.retrieve_plaintext_key(encryption_key)).to eq(plaintext_key)
    end

    it 'stores the retrieved plaintext key in cache' do
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)

      service.retrieve_plaintext_key(encryption_key)

      expect(Rails.cache).to have_received(:write)
    end

    it 'returns the correct plaintext key on successful cache write' do
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)

      expect(service.retrieve_plaintext_key(encryption_key)).to eq(plaintext_key)
    end
  end
end
