# frozen_string_literal: true

require 'aws-sdk-kms'
require 'rbnacl'
require 'singleton'
require 'benchmark'

class PorkyLib::Symmetric
  include Singleton

  CMK_KEY_ORIGIN = 'AWS_KMS'
  CMK_KEY_USAGE = 'ENCRYPT_DECRYPT'
  SYMMETRIC_KEY_SPEC = 'AES_256'

  EncryptedText = Struct.new(:ciphertext, :nonce, :statistics)
  DecryptedText = Struct.new(:plaintext, :statistics)

  def client
    require 'porky_lib/aws/kms/client' if PorkyLib::Config.config[:aws_client_mock]
    @client ||= Aws::KMS::Client.new
  end

  # rubocop:disable Style/OptionalBooleanParameter
  def create_key(tags, key_alias = nil, key_rotation_enabled = true)
    resp = client.create_key(key_usage: CMK_KEY_USAGE, origin: CMK_KEY_ORIGIN, tags: tags)
    key_id = resp.to_h[:key_metadata][:key_id]

    # Enable automatic key rotation for the newly created CMK
    enable_key_rotation(key_id) if key_rotation_enabled

    # Create an alias for the newly created CMK
    create_alias(key_id, key_alias) if key_alias

    key_id
  end
  # rubocop:enable Style/OptionalBooleanParameter

  def cmk_alias_exists?(key_alias)
    alias_list = client.list_aliases.to_h[:aliases]
    alias_list.each do |item|
      return true if item[:alias_name] == key_alias
    end

    false
  end

  def enable_key_rotation(key_id)
    client.enable_key_rotation(key_id: key_id)
  end

  def create_alias(key_id, key_alias)
    client.create_alias(target_key_id: key_id, alias_name: key_alias)
  end

  def generate_data_encryption_key(cmk_key_id, encryption_context = nil)
    resp = {}
    resp = client.generate_data_key(key_id: cmk_key_id, key_spec: SYMMETRIC_KEY_SPEC, encryption_context: encryption_context) if encryption_context
    resp = client.generate_data_key(key_id: cmk_key_id, key_spec: SYMMETRIC_KEY_SPEC) unless encryption_context

    [resp.plaintext, resp.ciphertext_blob]
  end

  def decrypt_data_encryption_key(ciphertext_key, encryption_context = nil)
    return client.decrypt(ciphertext_blob: ciphertext_key, encryption_context: encryption_context).plaintext if encryption_context

    resp = client.decrypt(ciphertext_blob: ciphertext_key)
    resp.plaintext
  end

  def encrypt(data, cmk_key_id, ciphertext_dek = nil, encryption_context = nil)
    return if data.nil? || cmk_key_id.nil?

    # Generate a new data encryption key or decrypt existing key, if provided
    plaintext_key = decrypt_data_encryption_key(ciphertext_dek, encryption_context) if ciphertext_dek
    ciphertext_key = ciphertext_dek if ciphertext_dek
    plaintext_key, ciphertext_key = generate_data_encryption_key(cmk_key_id, encryption_context) unless ciphertext_dek

    # Initialize the box
    secret_box = RbNaCl::SecretBox.new(plaintext_key)

    # First, make a nonce: A single-use value never repeated under the same key
    # The nonce isn't secret, and can be sent with the ciphertext.
    # The cipher instance has a nonce_bytes method for determining how many bytes should be in a nonce
    nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)

    # Encrypt a message with SecretBox
    ciphertext = secret_box.encrypt(nonce, data)

    # Securely delete the plaintext value from memory
    plaintext_key.replace(secure_delete_plaintext_key(plaintext_key.bytesize))

    [ciphertext_key, ciphertext, nonce]
  end

  def decrypt(ciphertext_dek, ciphertext, nonce, encryption_context = nil)
    return if ciphertext.nil? || ciphertext_dek.nil? || nonce.nil?

    # Decrypt the data encryption key
    plaintext_key = decrypt_data_encryption_key(ciphertext_dek, encryption_context)
    secret_box = RbNaCl::SecretBox.new(plaintext_key)

    should_reencrypt = false
    begin
      # Decrypt the message
      message = secret_box.decrypt(nonce, ciphertext)
    rescue RbNaCl::CryptoError
      # For backwards compatibility due to a code error in a previous release
      plaintext_key.replace(secure_delete_plaintext_key(plaintext_key.bytesize))
      message = secret_box.decrypt(nonce, ciphertext)
      should_reencrypt = true
    end

    # Securely delete the plaintext value from memory
    plaintext_key.replace(secure_delete_plaintext_key(plaintext_key.bytesize))

    [message, should_reencrypt]
  end

  def encrypt_with_benchmark(data, cmk_key_id, ciphertext_dek = nil, encryption_context = nil)
    return if data.nil? || cmk_key_id.nil?

    encryption_statistics = {}

    # Generate a new data encryption key or decrypt existing key, if provided
    if ciphertext_dek
      plaintext_key = benchmark_block(encryption_statistics, :decrypt_key) do
        decrypt_data_encryption_key(ciphertext_dek, encryption_context)
      end

      ciphertext_key = ciphertext_dek
    else
      plaintext_key, ciphertext_key = benchmark_block(encryption_statistics, :generate_key) do
        generate_data_encryption_key(cmk_key_id, encryption_context)
      end
    end

    nonce, ciphertext = benchmark_block(encryption_statistics, :encrypt) do
      # Initialize the box
      secret_box = RbNaCl::SecretBox.new(plaintext_key)

      # First, make a nonce: A single-use value never repeated under the same key
      # The nonce isn't secret, and can be sent with the ciphertext.
      # The cipher instance has a nonce_bytes method for determining how many bytes should be in a nonce
      nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)

      # Encrypt a message with SecretBox
      ciphertext = secret_box.encrypt(nonce, data)

      [nonce, ciphertext]
    end

    benchmark_block(encryption_statistics, :clear_key) do
      # Securely delete the plaintext value from memory
      plaintext_key.replace(secure_delete_plaintext_key(plaintext_key.bytesize))
    end

    [ciphertext_key, ciphertext, nonce, encryption_statistics]
  end

  def decrypt_with_benchmark(ciphertext_dek, ciphertext, nonce, encryption_context = nil)
    return if ciphertext.nil? || ciphertext_dek.nil? || nonce.nil?

    encryption_statistics = {}

    plaintext_key = benchmark_block(encryption_statistics, :decrypt_key) do
      # Decrypt the data encryption key
      decrypt_data_encryption_key(ciphertext_dek, encryption_context)
    end

    message, should_reencrypt = benchmark_block(encryption_statistics, :decrypt) do
      secret_box = RbNaCl::SecretBox.new(plaintext_key)

      should_reencrypt = false
      begin
        # Decrypt the message
        message = secret_box.decrypt(nonce, ciphertext)
      rescue RbNaCl::CryptoError
        # For backwards compatibility due to a code error in a previous release
        plaintext_key.replace(secure_delete_plaintext_key(plaintext_key.bytesize))
        message = secret_box.decrypt(nonce, ciphertext)
        should_reencrypt = true
      end

      [message, should_reencrypt, encryption_statistics]
    end

    benchmark_block(encryption_statistics, :clear_key) do
      # Securely delete the plaintext value from memory
      plaintext_key.replace(secure_delete_plaintext_key(plaintext_key.bytesize))
    end

    [message, should_reencrypt, encryption_statistics]
  end

  def secure_delete_plaintext_key(length)
    "\0" * length
  end

  def encrypt_with_key(plaintext, plaintext_key)
    # Initialize the box
    secret_box = RbNaCl::SecretBox.new(plaintext_key)

    # First, make a nonce: A single-use value never repeated under the same key
    # The nonce isn't secret, and can be sent with the ciphertext.
    # The cipher instance has a nonce_bytes method for determining how many bytes should be in a nonce
    nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)

    # Encrypt a message with SecretBox
    ciphertext = secret_box.encrypt(nonce, plaintext)

    EncryptedText.new(ciphertext, nonce, nil)
  end

  def decrypt_with_key(ciphertext, plaintext_key, nonce)
    # Initialize the box
    secret_box = RbNaCl::SecretBox.new(plaintext_key)

    # Decrypt the message
    plaintext = secret_box.decrypt(nonce, ciphertext)

    DecryptedText.new(plaintext, nil)
  end

  def encrypt_with_key_with_benchmark(plaintext, plaintext_key)
    encryption_statistics = {}

    nonce, ciphertext = benchmark_block(encryption_statistics, :encrypt) do
      # Initialize the box
      secret_box = RbNaCl::SecretBox.new(plaintext_key)

      # First, make a nonce: A single-use value never repeated under the same key
      # The nonce isn't secret, and can be sent with the ciphertext.
      # The cipher instance has a nonce_bytes method for determining how many bytes should be in a nonce
      nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)

      # Encrypt a message with SecretBox
      ciphertext = secret_box.encrypt(nonce, plaintext)

      [nonce, ciphertext]
    end

    EncryptedText.new(ciphertext, nonce, encryption_statistics)
  end

  def decrypt_with_key_with_benchmark(ciphertext, plaintext_key, nonce)
    encryption_statistics = {}

    plaintext = benchmark_block(encryption_statistics, :decrypt) do
      secret_box = RbNaCl::SecretBox.new(plaintext_key)

      # Decrypt the message
      plaintext = secret_box.decrypt(nonce, ciphertext)

      plaintext
    end

    DecryptedText.new(plaintext, encryption_statistics)
  end

  private

  def benchmark_block(statistics, stat_label)
    results = nil

    measurement = Benchmark.measure { results = yield }

    statistics[stat_label] = measurement

    results
  end
end
