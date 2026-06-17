# Pinned to 7.1 (the gem's Rails floor) so the CI matrix (Rails 7.1–8.0) can load
# this schema. Do NOT let a `db:schema:dump` on a newer Rails bump this version —
# older Rails can't parse a higher one (e.g. "Unknown migration version 8.1").
ActiveRecord::Schema[7.1].define(version: 1) do
  create_table :publishers, force: :cascade do |t|
    t.string :name
    t.string :slug
    t.date :founded_on
    t.timestamps
  end

  create_table :authors, force: :cascade do |t|
    t.string :name
    t.string :email
    t.timestamps
  end

  create_table :books, force: :cascade do |t|
    t.string :title
    t.string :subtitle
    t.string :slug
    t.text :blurb
    t.decimal :price, precision: 8, scale: 2
    t.decimal :purchase_price, precision: 8, scale: 2
    t.integer :pages
    t.date :published_on
    t.boolean :active, default: true
    t.integer :genre, default: 0
    t.json :metadata
    t.string :internal_token # exists, but never declared filterable anywhere
    t.references :publisher
    t.timestamps
  end

  create_table :authors_books, id: false, force: :cascade do |t|
    t.references :author
    t.references :book
  end

  create_table :reviews, force: :cascade do |t|
    t.references :book
    t.integer :rating
    t.text :body
    t.string :reviewer_name
    t.timestamps
  end

  # Polymorphic + STI — exercised only by the test suite (no playground UI).
  create_table :comments, force: :cascade do |t|
    t.text :body
    t.references :commentable, polymorphic: true
    t.timestamps
  end

  create_table :documents, force: :cascade do |t|
    t.string :type
    t.string :title
    t.text :body
    t.timestamps
  end

  # Active Storage (for attachment fields)
  create_table :active_storage_blobs, force: :cascade do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false
    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: :cascade do |t|
    t.string :name, null: false
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.bigint :blob_id, null: false
    t.datetime :created_at, null: false
    t.index [:blob_id]
    t.index %i[record_type record_id name blob_id], unique: true, name: 'index_active_storage_attachments_uniqueness'
  end

  create_table :active_storage_variant_records, force: :cascade do |t|
    t.bigint :blob_id, null: false
    t.string :variation_digest, null: false
    t.index %i[blob_id variation_digest], unique: true, name: 'index_active_storage_variant_records_uniqueness'
  end
end
