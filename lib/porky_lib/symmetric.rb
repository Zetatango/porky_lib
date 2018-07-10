# frozen_string_literal: true

require 'aws-sdk-kms'
require 'rbnacl'
require 'singleton'

class PorkyLib::Symmetric
  include Singleton

  CMK_KEY_ORIGIN = 'AWS_KMS'
  CMK_KEY_USAGE = 'ENCRYPT_DECRYPT'
  SYMMETRIC_KEY_SPEC = 'AES_256'

  def client
    require 'porky_lib/aws/kms/client' if PorkyLib::Config.config[:aws_client_mock]
    Aws::KMS::Client.new
  end

  def create_key(partner_guid, service_name, key_alias)
    PorkyLib::Config.logger.info("Creating a new master key for service: '#{service_name}' for partner: '#{partner_guid}'")
    kms_client = client
    resp = kms_client.create_key(key_usage: CMK_KEY_USAGE, origin: CMK_KEY_ORIGIN, tags: get_tags(partner_guid, service_name))
    key_id = resp.to_h[:key_metadata][:key_id]

    # Enable automatic key rotation for the newly created CMK
    enable_key_rotation(key_id, partner_guid, service_name)

    # Create an alias for the newly created CMK
    create_alias(key_id, key_alias, partner_guid, service_name) if key_alias

    key_id
  end

  def enable_key_rotation(key_id, partner_guid, service_name)
    PorkyLib::Config.logger.info("Enabling automatic key rotation for master key for service: '#{service_name}' for partner: '#{partner_guid}'")
    client.enable_key_rotation(key_id: key_id)
  end

  def create_alias(key_id, key_alias, partner_guid, service_name)
    PorkyLib::Config.logger.info("Setting alias as '#{key_alias}' for master key for service: '#{service_name}' for partner: '#{partner_guid}'")
    client.create_alias(target_key_id: key_id, alias_name: key_alias)
  end

  def encrypt(data, cmk_key_id)
    return if data.nil? || cmk_key_id.nil?

    # Generate a new data encryption key
    PorkyLib::Config.logger.info('Generating new data encryption key')
    kms_client = client
    resp = kms_client.generate_data_key(key_id: cmk_key_id, key_spec: SYMMETRIC_KEY_SPEC)
    plaintext_key = resp.to_h[:plaintext]
    ciphertext_key = resp.to_h[:ciphertext_blob]

    # Initialize the box
    secret_box = RbNaCl::SecretBox.new(plaintext_key)

    # First, make a nonce: A single-use value never repeated under the same key
    # The nonce isn't secret, and can be sent with the ciphertext.
    # The cipher instance has a nonce_bytes method for determining how many bytes should be in a nonce
    nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)

    # Encrypt a message with SecretBox
    PorkyLib::Config.logger.info('Beginning encryption')
    ciphertext = secret_box.encrypt(nonce, data)
    PorkyLib::Config.logger.info('Encryption complete')
    [ciphertext_key, ciphertext, nonce]
  end

  def decrypt(ciphertext_dek, ciphertext, nonce)
    return if ciphertext.nil? || ciphertext_dek.nil? || nonce.nil?

    # Decrypt the data encryption key
    PorkyLib::Config.logger.info('Decrypting data encryption key')
    kms_client = client
    resp = kms_client.decrypt(ciphertext_blob: ciphertext_dek)
    plaintext_key = resp.to_h[:plaintext]

    secret_box = RbNaCl::SecretBox.new(plaintext_key)
    PorkyLib::Config.logger.info('Beginning decryption')
    result = secret_box.decrypt(nonce, ciphertext)
    PorkyLib::Config.logger.info('Decryption complete')
    result
  end

  private

  # :nocov:
  def get_tags(partner_guid, service_name)
    tags = []
    tags << { tag_key: 'partner_guid', tag_value: partner_guid } unless partner_guid.nil?
    tags << { tag_key: 'service_name', tag_value: service_name } unless service_name.nil?

    tags
  end
  # :nocov:
end
