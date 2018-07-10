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
  let(:partner_guid) { "p_#{SecureRandom.base64(16)}" }
  let(:service_name) { 'wile_e' }
  let(:default_key_id) { 'alias/zetatango' }
  let(:bad_key_id) { 'alias/bad_key' }
  let(:bad_partner_guid) { 'bad_value' }
  let(:bad_service_name) { 'bad_value' }
  let(:key_alias) { 'alias/new_key' }
  let(:bad_alias) { 'alias/aws' }
  let(:dup_alias) { 'alias/dup' }

  before do
    PorkyLib::Config.configure(default_config)
    PorkyLib::Config.initialize_aws
  end

  it 'Encrypt returns non-null values for ciphertext key, ciphertext data, and nonce' do
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id)
    expect(key).not_to be nil
    expect(data).not_to be nil
    expect(nonce).not_to be nil
  end

  it 'Encrypt with bad CMK key ID raises NotFoundException' do
    expect do
      symmetric.encrypt(plaintext_data, bad_key_id)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Decrypt returns an expected value' do
    key, data, nonce = symmetric.encrypt(plaintext_data, default_key_id)
    result = symmetric.decrypt(key, data, nonce)
    expect(result).to eq(plaintext_data)
  end

  it 'Decrypt with bad nonce raises CryptoError' do
    key, data, = symmetric.encrypt(plaintext_data, default_key_id)
    expect do
      symmetric.decrypt(key, data, SecureRandom.hex(12))
    end.to raise_error(RbNaCl::CryptoError)
  end

  it 'Decrypt with bad ciphertext data raises CryptoError' do
    key, _, nonce = symmetric.encrypt(plaintext_data, default_key_id)
    expect do
      symmetric.decrypt(key, SecureRandom.base64(32), nonce)
    end.to raise_error(RbNaCl::CryptoError)
  end

  it 'Decrypt with bad ciphertext key raises InvalidCiphertextException' do
    _, data, nonce = symmetric.encrypt(plaintext_data, default_key_id)
    expect do
      symmetric.decrypt(SecureRandom.base64(32), data, nonce)
    end.to raise_error(Aws::KMS::Errors::InvalidCiphertextException)
  end

  it 'Create key returns non-null value for key ID' do
    key_id = symmetric.create_key(partner_guid, service_name, key_alias)
    expect(key_id).not_to be nil
  end

  it 'Create key raises TagException for invalid tags' do
    expect do
      symmetric.create_key(bad_partner_guid, bad_service_name, key_alias)
    end.to raise_error(Aws::KMS::Errors::TagException)
  end

  it 'Create key raises InvalidAliasNameException for invalid alias name' do
    expect do
      symmetric.create_key(partner_guid, service_name, bad_alias)
    end.to raise_error(Aws::KMS::Errors::InvalidAliasNameException)
  end

  it 'Create key raises AlreadyExistsException for duplicate alias name' do
    expect do
      symmetric.create_key(partner_guid, service_name, dup_alias)
    end.to raise_error(Aws::KMS::Errors::AlreadyExistsException)
  end

  it 'Create alias raise NotFoundException for unknown CMK key id' do
    expect do
      symmetric.create_alias(bad_key_id, key_alias, partner_guid, service_name)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Enable key rotation raise NotFoundException for unknown CMK key id' do
    expect do
      symmetric.enable_key_rotation(bad_key_id, partner_guid, service_name)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Using mock client in test environment' do
    expect(symmetric.client.inspect).to eq('#<Aws::KMS::Client (mocked)>')
  end
end
