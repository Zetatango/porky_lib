# frozen_string_literal: true

require 'rails/all'
require 'aws-sdk-s3'

class PorkyLib::CachingEncryptor
  class CachingEncryptorException < StandardError; end

  class EncryptionFailedException < CachingEncryptorException; end
  class DecryptionFailedException < CachingEncryptorException; end
  class InvalidParameterException < CachingEncryptorException; end

  def self.zt_encrypt(*args, &_block)
    data, partition_guid, encryption_epoch, expires_in, cmk_key_id = validate_encrypt_params(*args)

    kms = PorkyLib::KeyManagementService.new(partition_guid, expires_in, cmk_key_id)

    key_info = kms.find_or_create_encryption_key(encryption_epoch)

    plaintext_key = kms.retrieve_plaintext_key(key_info)

    encryption_result = PorkyLib::Symmetric.instance.encrypt_with_key(data, plaintext_key)

    # The value returned from this method is stored in the encrypted_{attr} field in the DB, but there isn't a way to tell the attr_encrypted library
    # the value of the nonce/IV to store or the value of the encryption key to store. As a result, we will store a JSON object as the encrypted_{attr},
    # with the raw byte values Base64 encoded.
    {
      key_guid: key_info.guid,
      # Store this with the data in case we need to decrypt outside the platform
      key: key_info.encrypted_data_encryption_key,
      data: Base64.encode64(encryption_result.ciphertext),
      nonce: Base64.encode64(encryption_result.nonce)
    }.to_json
  rescue PorkyLib::KeyManagementService::KeyManagementServiceException => e
    Rails.logger.error("KeyManagementService exception on encrypt: #{e.message}")

    raise EncryptionFailedException
  rescue RbNaCl::CryptoError, RbNaCl::LengthError => e
    Rails.logger.error("RbNaCl exception on encrypt: #{e.message}")

    raise EncryptionFailedException
  end

  def self.zt_decrypt(*args, &block)
    value, expires_in, cmk_key_id = validate_decrypt_params(*args)

    ciphertext_info = JSON.parse(value, symbolize_names: true)

    # Call the legacy decrypt function if there is no key_guid present
    return legacy_decrypt(*args, block) unless ciphertext_info.key?(:key_guid)

    key_guid = ciphertext_info[:key_guid]
    ciphertext = Base64.decode64(ciphertext_info[:data])
    nonce = Base64.decode64(ciphertext_info[:nonce])

    key_info = PorkyLib::EncryptionKey.find_by!(guid: key_guid)

    PorkyLib::Symmetric.instance.decrypt_with_key(
      ciphertext,
      PorkyLib::KeyManagementService.new(key_info.partition_guid, expires_in, cmk_key_id).retrieve_plaintext_key(key_info),
      nonce
    ).plaintext
  rescue JSON::JSONError => e
    Rails.logger.error("JSON parse error on decryption: #{e.message}")

    raise DecryptionFailedException
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Failed to find encryption key for guid #{key_guid} on decrypt: #{e.message}")

    raise DecryptionFailedException
  rescue PorkyLib::KeyManagementService::KeyManagementServiceException => e
    Rails.logger.error("KeyManagementService exception on decrypt: #{e.message}")

    raise DecryptionFailedException
  rescue RbNaCl::CryptoError, RbNaCl::LengthError => e
    Rails.logger.error("RbNaCl exception on decrypt: #{e.message}")

    raise DecryptionFailedException
  end

  def self.legacy_decrypt(*args, &_block)
    ciphertext_data = JSON.parse(args.first[:value], symbolize_names: true)
    ciphertext_key = Base64.decode64(ciphertext_data[:key])
    ciphertext = Base64.decode64(ciphertext_data[:data])
    nonce = Base64.decode64(ciphertext_data[:nonce])

    PorkyLib::Symmetric.instance.decrypt(ciphertext_key, ciphertext, nonce).first
  end
  private_class_method :legacy_decrypt

  def self.validate_encrypt_params(*args)
    data = args.first[:value]
    partition_guid = args.first[:partition_guid]
    encryption_epoch = args.first[:encryption_epoch]
    expires_in = args.first[:expires_in]
    cmk_key_id = args.first[:cmk_key_id]

    raise InvalidParameterException unless data.present? && partition_guid.present? && encryption_epoch.present? && expires_in.present? && cmk_key_id.present?

    [data, partition_guid, encryption_epoch, expires_in, cmk_key_id]
  end
  private_class_method :validate_encrypt_params

  def self.validate_decrypt_params(*args)
    value = args.first[:value]
    expires_in = args.first[:expires_in]
    cmk_key_id = args.first[:cmk_key_id]

    raise InvalidParameterException unless value.present? && expires_in.present? && cmk_key_id.present?

    [value, expires_in, cmk_key_id]
  end
  private_class_method :validate_decrypt_params
end
