# frozen_string_literal: true

require 'aws-sdk-kms'
require 'msgpack'

##
# This class is required for unit testing in order to mock response values from the AWS KMS SDK.
##
class Aws::KMS::Client
  MOCK_ALIAS_NAME_ALREADY_EXISTS = 'alias/dup'
  MOCK_INVALID_ALIAS_NAME = 'alias/aws'
  MOCK_INVALID_TAG_VALUE = 'bad_value'
  MOCK_NOT_FOUND_KEY_ID = 'bad_key'
  MOCK_VALID_KEY_USAGE = 'AES_256'
  PLAINTEXT_KEY_LENGTH = 32

  def create_key(key_usage:, origin:, tags:)
    raise Aws::KMS::Errors::TagException.new(nil, nil) if tags[0].value?(MOCK_INVALID_TAG_VALUE)

    Aws::KMS::Types::CreateKeyResponse.new(
      key_metadata: {
        aws_account_id: '123',
        creation_date: Time.now.utc.iso8601,
        description: '',
        enabled: true,
        key_id: SecureRandom.uuid,
        key_state: 'Enabled',
        key_usage: key_usage,
        origin: origin
      }
    )
  end

  def enable_key_rotation(key_id:)
    raise Aws::KMS::Errors::NotFoundException.new(nil, nil) if key_id.include?(MOCK_NOT_FOUND_KEY_ID)
  end

  def create_alias(target_key_id:, alias_name:)
    raise Aws::KMS::Errors::InvalidAliasNameException.new(nil, nil) if alias_name == MOCK_INVALID_ALIAS_NAME
    raise Aws::KMS::Errors::AlreadyExistsException.new(nil, nil) if alias_name == MOCK_ALIAS_NAME_ALREADY_EXISTS
    raise Aws::KMS::Errors::NotFoundException.new(nil, nil) if target_key_id.include?(MOCK_NOT_FOUND_KEY_ID)
  end

  def list_aliases
    {
      aliases: [
        {
          alias_arn: 'arn:aws:kms:us-east-2:111122223333:alias/example1',
          alias_name: 'alias/example1',
          target_key_id: '4da1e216-62d0-46c5-a7c0-5f3a3d2f8046'
        },
        {
          alias_arn: 'arn:aws:kms:us-east-2:444455556666:alias/new_key',
          alias_name: 'alias/new_key',
          target_key_id: '4da1e216-62d0-46c5-a7c0-5f3a3d2f8046'
        }
      ]
    }
  end

  def generate_data_key(key_id:, key_spec:, encryption_context: nil)
    raise Aws::KMS::Errors::InvalidKeyUsageException.new(nil, nil) unless key_spec == 'AES_256'
    raise Aws::KMS::Errors::NotFoundException.new(nil, nil) if key_id.include?(MOCK_NOT_FOUND_KEY_ID)

    plaintext = SecureRandom.random_bytes(PLAINTEXT_KEY_LENGTH)
    Aws::KMS::Types::GenerateDataKeyResponse.new(
      key_id: key_id,
      plaintext: plaintext,
      ciphertext_blob: [key_id, encryption_context, plaintext].to_msgpack.reverse
    )
  end

  def decrypt(ciphertext_blob:, encryption_context: nil)
    key_id, decoded_context, plaintext = MessagePack.unpack(ciphertext_blob.reverse)
    decoded_context = Hash[decoded_context.map { |k, v| [k.to_sym, v] }] if decoded_context
    raise Aws::KMS::Errors::InvalidCiphertextException.new(nil, nil) unless decoded_context == encryption_context

    Aws::KMS::Types::DecryptResponse.new(
      key_id: key_id,
      plaintext: plaintext
    )
  rescue MessagePack::MalformedFormatError
    raise Aws::KMS::Errors::InvalidCiphertextException.new(nil, nil)
  end

  def inspect
    '#<Aws::KMS::Client (mocked)>'
  end
end
