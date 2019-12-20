# frozen_string_literal: true

ActiveRecord::Schema.define do
  self.verbose = false

  create_table "encryption_keys", force: :cascade do |t|
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

  create_table "partition_providers", force: :cascade do |t|
    t.string "guid", null: false
    t.index ["guid"], name: "index_partition_providers_on_guid", unique: true
  end

  create_table "children", force: :cascade do |t|
    t.bigint "proxy_id"
    t.string "guid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "partition_guid", null: false
    t.datetime "encryption_epoch", null: false
    t.index ["guid"], name: "index_children_on_guid", unique: true
    t.index ["proxy_id"], name: "index_children_on_proxy_id"
  end

  create_table "proxies", force: :cascade do |t|
    t.string "guid"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "partition_provider_guid", null: false
    t.index ["guid"], name: "index_proxies_on_guid", unique: true
  end
end
