# frozen_string_literal: true

require 'active_record'
require 'active_support'

namespace :db do
  namespace :migrate do
    desc "Migrates the database by adding partition_guid and encryption_epoch to the specified model (must specify :model)"
    task :add_encryption_fields, [:model] => :environment do |_, args|
      model = args[:model].camelize

      abort 'Need to provide `model` as argument' if model.blank?

      `rails generate migration AddEncryptionKeysTo#{model} partition_guid:string \\
        encryption_epoch:datetime`
    end

    desc "Migrates the database by adding the encryption_keys table (must specify :model)"
    task :add_encryption_keys_table do
      `rails generate migration CreateEncryptionKeys guid:string \\
        partition_guid:string \\
        key_epoch:datetime \\
        encrypted_data_encryption_key:string \\
        version:string \\
        created_at:datetime \\
        updated_at:datetime`
    end
  end
end
