class CreateMarinaSchema < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :organizations, :slug, unique: true

    create_table :users do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.citext :email
      t.string :phone
      t.integer :role, null: false, default: 2 # 0=manager, 1=helper, 2=customer
      t.string :venmo_handle
      t.jsonb :notification_prefs, null: false, default: {}
      t.boolean :is_active, null: false, default: true
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :users, [:organization_id, :email], unique: true, where: "email IS NOT NULL"
    add_index :users, [:organization_id, :phone], unique: true, where: "phone IS NOT NULL"
    add_index :users, :role

    create_table :auth_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :short_code # 6-digit SMS code
      t.string :channel, null: false # 'email' | 'sms'
      t.string :purpose, null: false, default: 'login'
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
    add_index :auth_tokens, :token_digest, unique: true
    add_index :auth_tokens, :expires_at

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_seen_at
      t.datetime :expires_at, null: false
      t.datetime :absolute_expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :sessions, :token_digest, unique: true
    add_index :sessions, :expires_at

    create_table :locations do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :address
      t.string :timezone, null: false, default: "America/Chicago"
      t.integer :soft_cap_per_hour, null: false, default: 6
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :locations, [:organization_id, :slug], unique: true

    create_table :location_hours do |t|
      t.references :location, null: false, foreign_key: true
      t.integer :day_of_week, null: false # 0=Sun..6=Sat
      t.time :open_time
      t.time :close_time
      t.boolean :closed, null: false, default: false
      t.timestamps
    end
    add_index :location_hours, [:location_id, :day_of_week], unique: true

    create_table :slips do |t|
      t.references :location, null: false, foreign_key: true
      t.string :label, null: false
      t.string :slip_type, null: false # 'dry' | 'in_water'
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :slips, [:location_id, :label], unique: true
    add_index :slips, :slip_type

    create_table :boats do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :location, null: false, foreign_key: true
      t.references :slip, foreign_key: true
      t.string :name, null: false
      t.string :make
      t.string :model
      t.integer :year
      t.decimal :length_ft, precision: 5, scale: 1
      t.string :storage_type, null: false # 'dry' | 'in_water'
      t.text :notes
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :boats, :storage_type

    create_table :request_types do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :description
      t.boolean :requires_description, null: false, default: false
      t.string :applicable_storage_types, array: true, null: false, default: []
      t.string :icon, null: false, default: "anchor"
      t.string :color, null: false, default: "#2563eb"
      t.integer :sort_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :request_types, [:organization_id, :slug], unique: true
    add_index :request_types, :sort_order

    create_table :requests do |t|
      t.references :boat, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.references :request_type, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "to_do"
      t.datetime :scheduled_for, null: false
      t.text :description
      t.text :cancel_reason
      t.string :cancelled_by # 'customer' | 'staff'
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :requests, :status
    add_index :requests, :scheduled_for
    add_index :requests, [:location_id, :scheduled_for]

    create_table :request_notes do |t|
      t.references :request, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.string :visibility, null: false, default: "private" # 'public' | 'private'
      t.timestamps
    end
    add_index :request_notes, [:request_id, :created_at]

    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :request, foreign_key: true
      t.string :event, null: false
      t.string :channel, null: false # 'email' | 'sms'
      t.string :status, null: false, default: "pending" # pending|sent|delivered|bounced|failed
      t.string :to_address, null: false
      t.string :provider_id
      t.text :error
      t.integer :attempts, null: false, default: 0
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :failed_at
      t.timestamps
    end
    add_index :notifications, [:user_id, :event]
    add_index :notifications, :status
    add_index :notifications, :provider_id

    create_table :audit_logs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.string :action, null: false # create|update|destroy|transition|note
      t.jsonb :changes_data, null: false, default: {}
      t.string :ip_address
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, [:auditable_type, :auditable_id]
    add_index :audit_logs, [:organization_id, :created_at]
  end
end
