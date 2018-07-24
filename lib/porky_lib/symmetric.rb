# frozen_string_literal: true

require 'aws-sdk-kms'
require 'rbnacl/libsodium'
require 'singleton'

class PorkyLib::Symmetric
  include Singleton

  CMK_KEY_ORIGIN = 'AWS_KMS'
  CMK_KEY_USAGE = 'ENCRYPT_DECRYPT'
  SYMMETRIC_KEY_SPEC = 'AES_256'

  def client
    require 'porky_lib/aws/kms/client' if PorkyLib::Config.config[:aws_client_mock]
    @client ||= Aws::KMS::Client.new
  end

  def create_key(tags, key_alias = nil, key_rotation_enabled = true)
    PorkyLib::Config.logger.info("Creating a new master key")
    resp = client.create_key(key_usage: CMK_KEY_USAGE, origin: CMK_KEY_ORIGIN, tags: tags)
    key_id = resp.to_h[:key_metadata][:key_id]

    # Enable automatic key rotation for the newly created CMK
    enable_key_rotation(key_id) if key_rotation_enabled

    # Create an alias for the newly created CMK
    create_alias(key_id, key_alias) if key_alias

    key_id
  end

  def enable_key_rotation(key_id)
    PorkyLib::Config.logger.info("Enabling automatic key rotation for master key: '#{key_id}'")
    client.enable_key_rotation(key_id: key_id)
  end

  def create_alias(key_id, key_alias)
    PorkyLib::Config.logger.info("Setting alias as '#{key_alias}' for master key: '#{key_id}'")
    client.create_alias(target_key_id: key_id, alias_name: key_alias)
  end

  def generate_data_encryption_key(cmk_key_id, encryption_context = nil)
    PorkyLib::Config.logger.info('Generating new data encryption key')
    resp = {}
    resp = client.generate_data_key(key_id: cmk_key_id, key_spec: SYMMETRIC_KEY_SPEC, encryption_context: encryption_context) if encryption_context
    resp = client.generate_data_key(key_id: cmk_key_id, key_spec: SYMMETRIC_KEY_SPEC) unless encryption_context

    [resp.to_h[:plaintext], resp.to_h[:ciphertext_blob]]
  end

  def decrypt_data_encryption_key(ciphertext_key, encryption_context = nil)
    PorkyLib::Config.logger.info('Decrypting data encryption key')
    resp = {}
    resp = client.decrypt(ciphertext_blob: ciphertext_key, encryption_context: encryption_context) if encryption_context
    resp = client.decrypt(ciphertext_blob: ciphertext_key) unless encryption_context

    resp.to_h[:plaintext]
  end

  def encrypt(data, cmk_key_id, ciphertext_dek = nil, encryption_context = nil)
    return if data.nil? || cmk_key_id.nil?

    # Generate a new data encryption key or decrypt existing key, if provided
    plaintext_key = decrypt_data_encryption_key(ciphertext_dek, encryption_context) if ciphertext_dek
    ciphertext_key = ciphertext_dek if ciphertext_dek
    plaintext_key, ciphertext_key = generate_data_encryption_key(cmk_key_id, encryption_context) unless ciphertext_dek

    # Initialize the box
    secret_box = RbNaCl::SecretBox.new(plaintext_key)

    # rubocop:disable Lint/UselessAssignment
    plaintext_key = secure_delete_plaintext_key(plaintext_key.bytesize)
    # rubocop:enable Lint/UselessAssignment

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

  def decrypt(ciphertext_dek, ciphertext, nonce, encryption_context = nil)
    return if ciphertext.nil? || ciphertext_dek.nil? || nonce.nil?

    # Decrypt the data encryption key
    plaintext_key = decrypt_data_encryption_key(ciphertext_dek, encryption_context)

    secret_box = RbNaCl::SecretBox.new(plaintext_key)

    # rubocop:disable Lint/UselessAssignment
    plaintext_key = secure_delete_plaintext_key(plaintext_key.bytesize)
    # rubocop:enable Lint/UselessAssignment

    PorkyLib::Config.logger.info('Beginning decryption')
    result = secret_box.decrypt(nonce, ciphertext)
    PorkyLib::Config.logger.info('Decryption complete')
    result
  end

  def secure_delete_plaintext_key(length)
    "\0" * length
  end
end
