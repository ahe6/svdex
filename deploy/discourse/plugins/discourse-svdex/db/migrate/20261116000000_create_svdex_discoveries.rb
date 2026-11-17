# frozen_string_literal: true
class CreateSvdexDiscoveries < ActiveRecord::Migration[7.2]
  def change
    create_table :svdex_discoveries do |t|
      t.bigint :entity_user_id
      t.bigint :contributor_user_id
      t.bigint :original_entity_user_id, null: false
      t.bigint :original_contributor_user_id
      t.string :entity_kind, null: false
      t.string :provenance, null: false, default: "staff_added"
      t.string :status, null: false, default: "accepted"
      t.datetime :listed_at
      t.bigint :superseded_by_id
      t.timestamps null: false
    end
    add_index :svdex_discoveries, :entity_user_id, unique: true, where: "superseded_by_id IS NULL", name: "svdex_discovery_canonical_entity"
    add_index :svdex_discoveries, [:contributor_user_id, :listed_at]
    add_foreign_key :svdex_discoveries, :users, column: :entity_user_id, on_delete: :nullify
    add_foreign_key :svdex_discoveries, :users, column: :contributor_user_id, on_delete: :nullify
    create_table :svdex_discovery_events do |t|
      t.bigint :discovery_id, null: false
      t.bigint :acting_user_id
      t.string :action, null: false
      t.text :reason, null: false
      t.jsonb :before_state, null: false, default: {}
      t.jsonb :after_state, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :svdex_discovery_events, [:discovery_id, :id]
    add_check_constraint :svdex_discoveries, "entity_kind IN ('companies','funds','people') AND provenance IN ('discovered','self_listed','staff_added','imported') AND status IN ('accepted','withdrawn','disputed')", name: "svdex_discovery_vocabulary"
  end
end
