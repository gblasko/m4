class AddPushoverSupport < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :pushover_group_key, :string
    add_column :users,     :pushover_user_key,  :string

    create_table :location_subscriptions do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      # Last-known sync state from Pushover (e.g. "synced", "missing_user_key").
      # Used for surfacing problems in the admin UI; not authoritative.
      t.string :pushover_member_status
      t.timestamps
    end
    add_index :location_subscriptions, [:user_id, :location_id], unique: true
  end
end
