# frozen_string_literal: true

require 'rails/all'
require 'logger'

class PorkyLib::KeyManagementService
  class KeyManagementServiceException < StandardError; end
  class InvalidParameterException < KeyManagementServiceException; end
  class KeyGenerationException < KeyManagementServiceException; end
  class KeyCreateException < KeyManagementServiceException; end
  class KeyRetrieveException < KeyManagementServiceException; end

  KEY_MANAGEMENT_SERVICE_CACHE_NAMESPACE = :key_management_service
  KEY_VERSION = 'KeyManagementService::V1'

  RECORD_NOT_UNIQUE_REGEX = /has already been taken/.freeze

  def initialize(partition_guid, expires_in, cmk_key_id)
    raise InvalidParameterException unless partition_guid.present? && expires_in.present? && cmk_key_id.present?

    @partition_guid = partition_guid
    @expire_in = expires_in
    @cmk_key_id = cmk_key_id
  end

  def self.encryption_key_epoch(datetime)
    datetime.utc.beginning_of_year
  end

  def find_or_create_encryption_key(encryption_epoch)
    find(encryption_epoch) || create(encryption_epoch)
  end

  def retrieve_plaintext_key(encryption_key)
    raise InvalidParameterException unless encryption_key.present?

    read_plaintext_key(encryption_key) || decrypt_encryption_key(encryption_key)
  end

  private

  def read_plaintext_key(encryption_key)
    Rails.cache.read(encryption_key.guid, namespace: KEY_MANAGEMENT_SERVICE_CACHE_NAMESPACE)
  rescue Redis::BaseError => e
    Rails.logger.error("Failed to read cache for encryption key #{encryption_key.guid}: #{e.message}")

    nil
  end

  def decrypt_encryption_key(encryption_key)
    decoded_key = Base64.decode64(encryption_key.encrypted_data_encryption_key)

    plaintext_key = PorkyLib::Symmetric.instance.decrypt_data_encryption_key(decoded_key)

    cache_plaintext_key(encryption_key, plaintext_key)

    plaintext_key
  rescue Aws::Errors::ServiceError => e
    Rails.logger.error("Failed to decrypt data encryption key: #{e.message}")

    raise KeyRetrieveException
  end

  def cache_plaintext_key(encryption_key, plaintext_key)
    Rails.cache.write(encryption_key.guid, plaintext_key, namespace: KEY_MANAGEMENT_SERVICE_CACHE_NAMESPACE,
                      expires_in: @expires_in)
  rescue Redis::BaseError => e
    Rails.logger.error("Failed to cache encryption key: #{e.message}")
  end

  def create(encryption_epoch)
    plaintext_key, data_encryption_key = PorkyLib::Symmetric.instance.generate_data_encryption_key(@cmk_key_id)

    encoded_key = Base64.encode64(data_encryption_key)

    key = PorkyLib::EncryptionKey.create!(partition_guid: @partition_guid, key_epoch: encryption_epoch,
                                encrypted_data_encryption_key: encoded_key, version: KEY_VERSION)

    cache_plaintext_key(key, plaintext_key)

    key
  rescue Aws::Errors::ServiceError => e
    Rails.logger.error("Failed to generate data encryption key: #{e.message}")

    raise KeyGenerationException
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to save encryption key: #{e.message}")

    raise KeyCreateException unless e.message.match?(RECORD_NOT_UNIQUE_REGEX)

    Rails.logger.info('Retrying find after failed EncryptionKey create')

    find(encryption_epoch)
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error("Failed to save encryption key, retrying find: #{e.message}")

    find(encryption_epoch)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("Failed to save encryption key: #{e.message}")

    raise KeyCreateException
  end

  def find(encryption_epoch)
    PorkyLib::EncryptionKey.find_by(partition_guid: @partition_guid, key_epoch: encryption_epoch)
  end
end
