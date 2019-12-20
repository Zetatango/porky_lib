# frozen_string_literal: true

require './spec/models/proxy'
require 'attr_encrypted'

class Child < PorkyLib::ApplicationRecord
  include PorkyLib::PartitionProvider
  include PorkyLib::HasEncryptedAttributes
  include PorkyLib::HasGuid

  partition_provider :proxy

  belongs_to :proxy, required: true

  attr_encrypted :value, encryptor: PorkyLib::CachingEncryptor, encrypt_method: :zt_encrypt, decrypt_method: :zt_decrypt,
                         encode: true, partition_guid: proc { |object| object.generate_partition_guid },
                         encryption_epoch: proc { |object| object.generate_encryption_epoch }, cmk_key_id: 'alias/zetatango',
                         expires_in: 5.minutes

  has_guid 'c'
  validates_with PorkyLib::StringValidator, fields: %i[guid]

  def generate_partition_guid
    return partition_guid if partition_guid.present?

    self.partition_guid = provider_partition_guid
  end

  def generate_encryption_epoch
    return encryption_epoch if encryption_epoch.present?

    self.encryption_epoch = provider_encryption_epoch
  end
end
