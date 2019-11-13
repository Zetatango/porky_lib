# frozen_string_literal: true

require 'active_record'
require 'active_support'

namespace :db do
  namespace :migrate do
    desc "Migrates the database by adding partition_guid and encryption_epoch to the specified model (must specify :model)"
    task :add_encryption_fields, [:model] => :environment do |_, args|
      model = args[:model].to_sym

      abort 'Need to provide `model` as argument' if model.blank?

      ActiveRecord::Base.establish_connection(Rails.application.config.database_configuration[Rails.env])
      ActiveRecord::Migration.add_column model, "partition_guid", :string
      ActiveRecord::Migration.add_column model, "encryption_epoch", :datetime
    end

    desc "Migrates the database by adding the encryption_keys table (must specify :model)"
    task :add_encryption_keys_table do
      ActiveRecord::Base.establish_connection(Rails.application.config.database_configuration[Rails.env])

      abort 'encryption_keys table already exists' if ActiveRecord::Base.connection.tables.include?("encryption_keys")

      ActiveRecord::Migration.create_table :encryption_keys do |t|
        t.string "guid", null: false
        t.string "partition_guid", null: false
        t.datetime "key_epoch", null: false
        t.string "encrypted_data_encryption_key", null: false
        t.string "version", null: false
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index ["guid"], name: "index_encryption_keys_on_guid", unique: true
        t.index %w[partition_guid key_epoch], name: "index_encryption_keys", unique: true
      end
    end
  end
end
