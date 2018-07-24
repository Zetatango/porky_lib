# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::Symmetric, type: :request do
  let(:symmetric) { PorkyLib::Symmetric.instance }
  let(:default_config) do
    { aws_region: 'us-east-1',
      aws_key_id: 'abc123',
      aws_key_secret: 'def456' }
  end
  let(:plaintext_data) { 'abc123' }
  let(:default_tags) do
    [
      { key1: 'value 1' },
      { key2: 'value 2' }
    ]
  end
  let(:default_key_id) { 'alias/zetatango' }
  let(:default_encryption_context) do
    {
      encryptionContextKey: 'encryption context value'
    }
  end
  let(:bad_key_id) { 'alias/bad_key' }
  let(:bad_tags) do
    [
      { key1: 'bad_value' }
    ]
  end
  let(:key_alias) { 'alias/new_key' }
  let(:bad_alias) { 'alias/aws' }
  let(:dup_alias) { 'alias/dup' }
  let(:bad_encryption_context) do
    {
      encryptionContextKey: 'bad encryption context'
    }
  end
  let(:data_encryption_key_length) { 256 / 8 } # 256-bit key in bytes

  before do
    PorkyLib::Config.configure(default_config)
    PorkyLib::Config.initialize_aws
  end

  it 'Generate data encryption key returns non-null values for plaintext_key and ciphertext_key' do
    plaintext_key, ciphertext_key = symmetric.generate_data_encryption_key(default_key_id, default_encryption_context)
    expect(plaintext_key).not_to be nil
    expect(ciphertext_key).not_to be nil
  end

  it 'Generate data encryption key with bad CMK key ID raises NotFoundException' do
    expect do
      symmetric.generate_data_encryption_key(bad_key_id, default_encryption_context)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Encrypt returns non-null values for ciphertext key, ciphertext data, and nonce' do
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id, nil, default_encryption_context)
    expect(key).not_to be nil
    expect(data).not_to be nil
    expect(nonce).not_to be nil
  end

  it 'Encrypt returns non-null values for ciphertext key, ciphertext data, and nonce with existing data encryption key' do
    _, ciphertext_key = symmetric.generate_data_encryption_key(default_key_id, default_encryption_context)
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id, ciphertext_key, default_encryption_context)
    expect(key).to eq(ciphertext_key)
    expect(data).not_to be nil
    expect(nonce).not_to be nil
  end

  it 'Encrypt returns non-null values with no encryption context for ciphertext key, ciphertext data, and nonce' do
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id)
    expect(key).not_to be nil
    expect(data).not_to be nil
    expect(nonce).not_to be nil
  end

  it 'Encrypt with bad CMK key ID raises NotFoundException' do
    expect do
      symmetric.encrypt(plaintext_data, bad_key_id, nil, default_encryption_context)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Decrypt returns an expected value' do
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id, nil, default_encryption_context)
    result = symmetric.decrypt(key, data, nonce, default_encryption_context)
    expect(result).to eq(plaintext_data)
  end

  it 'Decrypt with no encryption context returns an expected value' do
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id)
    result = symmetric.decrypt(key, data, nonce, nil)
    expect(result).to eq(plaintext_data)
  end

  it 'Decrypt with bad nonce raises CryptoError' do
    key, data, = symmetric.encrypt(plaintext_data, default_key_id, nil, default_encryption_context)
    expect do
      symmetric.decrypt(key, data, SecureRandom.hex(12), default_encryption_context)
    end.to raise_error(RbNaCl::CryptoError)
  end

  it 'Decrypt with bad encryption context raises InvalidCiphertextException' do
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id, nil, default_encryption_context)
    expect do
      symmetric.decrypt(key, data, nonce, bad_encryption_context)
    end.to raise_error(Aws::KMS::Errors::InvalidCiphertextException)
  end

  it 'Decrypt with bad ciphertext data raises CryptoError' do
    key, _, nonce = symmetric.encrypt(plaintext_data, default_key_id, nil, default_encryption_context)
    expect do
      symmetric.decrypt(key, SecureRandom.base64(32), nonce, default_encryption_context)
    end.to raise_error(RbNaCl::CryptoError)
  end

  it 'Decrypt with slightly modified data raises CryptoError' do
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id, nil, default_encryption_context)
    data_bytes = data.unpack('c*')
    data_bytes[0] = data_bytes[0] + 1
    data = data_bytes.pack('c*')
    expect do
      symmetric.decrypt(key, data, nonce, default_encryption_context)
    end.to raise_error(RbNaCl::CryptoError)
  end

  it 'Decrypt with bad ciphertext key raises InvalidCiphertextException' do
    _, data, nonce = symmetric.encrypt(plaintext_data, default_key_id, nil, default_encryption_context)
    expect do
      symmetric.decrypt(SecureRandom.base64(32), data, nonce, default_encryption_context)
    end.to raise_error(Aws::KMS::Errors::InvalidCiphertextException)
  end

  it 'Create key returns non-null value for key ID' do
    key_id = symmetric.create_key(default_tags, key_alias)
    expect(key_id).not_to be nil
  end

  it 'Create key raises TagException for invalid tags' do
    expect do
      symmetric.create_key(bad_tags, key_alias)
    end.to raise_error(Aws::KMS::Errors::TagException)
  end

  it 'Create key raises InvalidAliasNameException for invalid alias name' do
    expect do
      symmetric.create_key(default_tags, bad_alias)
    end.to raise_error(Aws::KMS::Errors::InvalidAliasNameException)
  end

  it 'Create key raises AlreadyExistsException for duplicate alias name' do
    expect do
      symmetric.create_key(default_tags, dup_alias)
    end.to raise_error(Aws::KMS::Errors::AlreadyExistsException)
  end

  it 'Create alias raise NotFoundException for unknown CMK key id' do
    expect do
      symmetric.create_alias(bad_key_id, key_alias)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Enable key rotation raise NotFoundException for unknown CMK key id' do
    expect do
      symmetric.enable_key_rotation(bad_key_id)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Securely deleting plaintext key returns a string of null characters matching the length of the key' do
    plaintext_key, = symmetric.generate_data_encryption_key(default_key_id, default_encryption_context)
    plaintext_key = symmetric.secure_delete_plaintext_key(plaintext_key.bytesize)
    expect(plaintext_key).to eq("\0" * data_encryption_key_length)
  end

  it 'Using mock client in test environment' do
    expect(symmetric.client.inspect).to eq('#<Aws::KMS::Client (mocked)>')
  end
end
