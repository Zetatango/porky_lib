# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'active_record'
require 'active_support'
import 'lib/tasks/file.rake'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :database_migration do
  desc "Migrates the database by adding partition_guid and encryption_epoch to the specified model"
  task :add_encryption_fields_to_model, %i[partition_guid encryption_epoch] => [:environment] do |_, args|
    model = args[:model]

    return puts 'Need to provide `model` as argument' if model.blank?

    ActiveRecord::Migration.add_column model, "partition_guid", :string
    ActiveRecord::Migration.add_column model, "encryption_epoch", :datetime
  end

  desc "Migrates the database by adding the encryption_keys table"
  task :add_encryption_keys_table do
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
