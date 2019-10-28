# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::CachingEncryptor do
  let(:caching_encryptor) { described_class.new }
  let(:expires_in) { 5.minutes }
  let(:cmk_key_id) { 'alias/zetatango' }

  let(:kms) { instance_double(PorkyLib::KeyManagementService) }
  let(:encryption_key) { create :encryption_key }
  let(:plaintext_key) { SecureRandom.base58(16) }
  let(:plaintext) { SecureRandom.base58(16) }
  let(:ciphertext) { SecureRandom.base58(16) }
  let(:nonce) { SecureRandom.base58(16) }
  let(:porkylib_encryption_info) do
    result = OpenStruct.new

    result.ciphertext = ciphertext
    result.nonce = nonce

    result
  end
  let(:porkylib_decryption_info) do
    result = OpenStruct.new

    result.plaintext = plaintext

    result
  end
  let(:encryption_args) do
    [{
      value: plaintext,
      partition_guid: encryption_key.partition_guid,
      encryption_epoch: encryption_key.key_epoch,
      expires_in: expires_in,
      cmk_key_id: cmk_key_id
    }]
  end
  let(:decryption_args) do
    [{
      value: {
        key_guid: encryption_key.guid,
        key: encryption_key.encrypted_data_encryption_key,
        data: Base64.encode64(ciphertext),
        nonce: Base64.encode64(nonce)
      }.to_json,
      expires_in: expires_in,
      cmk_key_id: cmk_key_id
    }]
  end

  encryption_params = %i[value partition_guid encryption_epoch expires_in cmk_key_id]
  decryption_params = %i[value expires_in cmk_key_id]

  before do
    allow(PorkyLib::KeyManagementService).to receive(:new).and_return(kms)
    allow(kms).to receive(:find_or_create_encryption_key).and_return(encryption_key)
    allow(kms).to receive(:retrieve_plaintext_key).and_return(plaintext_key)

    allow(PorkyLib::Symmetric.instance).to receive(:encrypt_with_key).and_return(porkylib_encryption_info)
    allow(PorkyLib::Symmetric.instance).to receive(:decrypt_with_key).and_return(porkylib_decryption_info)
  end

  describe '#encrypt' do
    encryption_params.each do |param|
      it "raises an InvalidParameterException when #{param} is nil" do
        expect do
          caching_encryptor.encrypt(*generate_invalid_encrypt_params(param, nil))
        end.to raise_exception(PorkyLib::CachingEncryptor::InvalidParameterException)
      end

      it "raises an InvalidParameterException when #{param} is empty" do
        expect do
          caching_encryptor.encrypt(*generate_invalid_encrypt_params(param, ''))
        end.to raise_exception(PorkyLib::CachingEncryptor::InvalidParameterException)
      end
    end

    it 'raises an EncryptionFailedException on KeyManagementService InvalidParameterException' do
      allow(PorkyLib::KeyManagementService).to receive(:new).and_raise(PorkyLib::KeyManagementService::InvalidParameterException)

      expect { caching_encryptor.encrypt(*encryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::EncryptionFailedException)
    end

    it 'raises an EncryptionFailedException on KeyManagementService KeyGenerationException' do
      allow(kms).to receive(:find_or_create_encryption_key).and_raise(PorkyLib::KeyManagementService::KeyGenerationException)

      expect { caching_encryptor.encrypt(*encryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::EncryptionFailedException)
    end

    it 'raises an EncryptionFailedException on KeyManagementService KeyCreateException' do
      allow(kms).to receive(:find_or_create_encryption_key).and_raise(PorkyLib::KeyManagementService::KeyCreateException)

      expect { caching_encryptor.encrypt(*encryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::EncryptionFailedException)
    end

    it 'raises an EncryptionFailedException on RbNaCl CryptoError' do
      allow(PorkyLib::Symmetric.instance).to receive(:encrypt_with_key).and_raise(RbNaCl::CryptoError)

      expect { caching_encryptor.encrypt(*encryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::EncryptionFailedException)
    end

    it 'raises an EncryptionFailedException on RbNaCl LengthError' do
      allow(PorkyLib::Symmetric.instance).to receive(:encrypt_with_key).and_raise(RbNaCl::LengthError)

      expect { caching_encryptor.encrypt(*encryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::EncryptionFailedException)
    end

    it 'returns a correct valid JSON struct' do
      encryption_info = caching_encryptor.encrypt(*encryption_args)

      expect { JSON.parse(encryption_info) }.not_to raise_exception
    end

    it 'returns a correct JSON struct with the correct fields' do
      encryption_info = JSON.parse(caching_encryptor.encrypt(*encryption_args), symbolize_names: true)

      expect(encryption_info).to have_key(:key_guid)
      expect(encryption_info).to have_key(:key)
      expect(encryption_info).to have_key(:data)
      expect(encryption_info).to have_key(:nonce)
    end

    it 'returns a correct JSON struct with the correct values' do
      encryption_info = JSON.parse(caching_encryptor.encrypt(*encryption_args), symbolize_names: true)

      expect(encryption_info[:key_guid]).to eq(encryption_key.guid)
      expect(encryption_info[:key]).to eq(encryption_key.encrypted_data_encryption_key)
      expect(encryption_info[:data]).to eq(Base64.encode64(ciphertext))
      expect(encryption_info[:nonce]).to eq(Base64.encode64(nonce))
    end
  end

  describe '#decrypt' do
    decryption_params.each do |param|
      it "raises an InvalidParameterException when #{param} is nil" do
        expect do
          caching_encryptor.decrypt(*generate_invalid_decrypt_params(param, nil))
        end.to raise_exception(PorkyLib::CachingEncryptor::InvalidParameterException)
      end

      it "raises an InvalidParameterException when #{param} is empty" do
        expect do
          caching_encryptor.decrypt(*generate_invalid_decrypt_params(param, ''))
        end.to raise_exception(PorkyLib::CachingEncryptor::InvalidParameterException)
      end
    end

    it 'raises a DecryptionFailedException on a JSON parse error' do
      decryption_args = [{
        value: 'this is not { valid => json }: here',
        expires_in: expires_in,
        cmk_key_id: cmk_key_id
      }]

      expect { caching_encryptor.decrypt(*decryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::DecryptionFailedException)
    end

    # rubocop:disable ExampleLength
    it 'raises a DecryptionFailedException on an EncryptionKey not found error' do
      decryption_args = [{
        value: {
          key_guid: "dek_#{SecureRandom.base58(16)}",
          key: encryption_key.encrypted_data_encryption_key,
          data: ciphertext,
          nonce: nonce
        }.to_json,
        expires_in: expires_in,
        cmk_key_id: cmk_key_id
      }]

      expect { caching_encryptor.decrypt(*decryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::DecryptionFailedException)
    end

    it 'calls the legacy decrypt function when key_guid is not present' do
      allow(PorkyLib::Symmetric.instance).to receive(:decrypt).and_return(plaintext)

      decryption_args = [{
        value: {
          key: encryption_key.encrypted_data_encryption_key,
          data: ciphertext,
          nonce: nonce
        }.to_json,
        expires_in: expires_in,
        cmk_key_id: cmk_key_id
      }]

      caching_encryptor.decrypt(*decryption_args)

      expect(PorkyLib::Symmetric.instance).to have_received(:decrypt)
    end
    # rubocop:enable ExampleLength

    it 'raises a DecryptionFailedException on KeyManagementService InvalidParameterException' do
      allow(PorkyLib::KeyManagementService).to receive(:new).and_raise(PorkyLib::KeyManagementService::InvalidParameterException)

      expect { caching_encryptor.decrypt(*decryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::DecryptionFailedException)
    end

    it 'raises a DecryptionFailedException on KeyManagementService KeyRetrieveException' do
      allow(PorkyLib::KeyManagementService).to receive(:new).and_raise(PorkyLib::KeyManagementService::KeyRetrieveException)

      expect { caching_encryptor.decrypt(*decryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::DecryptionFailedException)
    end

    it 'raises a DecryptionFailedException on RbNaCl CryptoError' do
      allow(PorkyLib::Symmetric.instance).to receive(:decrypt_with_key).and_raise(RbNaCl::CryptoError)

      expect { caching_encryptor.decrypt(*decryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::DecryptionFailedException)
    end

    it 'raises a DecryptionFailedException on RbNaCl LengthError' do
      allow(PorkyLib::Symmetric.instance).to receive(:decrypt_with_key).and_raise(RbNaCl::LengthError)

      expect { caching_encryptor.decrypt(*decryption_args) }.to raise_exception(PorkyLib::CachingEncryptor::DecryptionFailedException)
    end

    it 'returns decrypted data' do
      expect(caching_encryptor.decrypt(*decryption_args)).to eq(plaintext)
    end
  end

  private

  def generate_invalid_encrypt_params(variable, value)
    encryption_args.first[variable] = value

    encryption_args
  end

  def generate_invalid_decrypt_params(variable, value)
    decryption_args.first[variable] = value

    decryption_args
  end
end
