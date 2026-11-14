# frozen_string_literal: true
class CreateSvdexInterestIndications < ActiveRecord::Migration[7.2]
  def change
    create_table :svdex_interest_indications do |t|
      t.bigint :user_id, null: false
      t.bigint :organization_id, null: false
      t.string :side, null: false
      t.string :market, null: false
      t.string :currency, null: false, default: "USD"
      t.bigint :amount_cents, null: false
      t.bigint :topic_id
      t.boolean :source_was_restricted, null: false, default: false
      t.datetime :expires_at, null: false
      t.datetime :withdrawn_at
      t.timestamps null: false
    end
    add_index :svdex_interest_indications, [:user_id, :organization_id, :side], unique: true, name: "svdex_interest_canonical"
    add_index :svdex_interest_indications, [:organization_id, :side, :expires_at], name: "svdex_interest_totals"
    add_foreign_key :svdex_interest_indications, :users, on_delete: :cascade
    add_foreign_key :svdex_interest_indications, :users, column: :organization_id, on_delete: :cascade
    add_foreign_key :svdex_interest_indications, :topics, on_delete: :nullify
    add_check_constraint :svdex_interest_indications, "amount_cents > 0 AND amount_cents <= 9007199254740991", name: "svdex_interest_amount"
    add_check_constraint :svdex_interest_indications, "side IN ('buy', 'sell') AND market IN ('primary', 'secondary', 'either') AND (side <> 'sell' OR market = 'secondary') AND currency = 'USD'", name: "svdex_interest_kind"
  end
end
