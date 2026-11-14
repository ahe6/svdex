# frozen_string_literal: true
class CreateSvdexOfferingBids < ActiveRecord::Migration[7.2]
  def change
    create_table :svdex_offering_bids do |t|
      t.bigint :user_id, null: false
      t.bigint :organization_id, null: false
      t.bigint :topic_id, null: false
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.text :proposed_terms, null: false
      t.datetime :confirmed_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :withdrawn_at
      t.timestamps null: false
    end
    add_index :svdex_offering_bids, [:user_id, :topic_id], unique: true, name: "svdex_bid_per_offering"
    add_foreign_key :svdex_offering_bids, :users, on_delete: :cascade
    add_foreign_key :svdex_offering_bids, :users, column: :organization_id, on_delete: :cascade
    add_foreign_key :svdex_offering_bids, :topics, on_delete: :cascade
    add_check_constraint :svdex_offering_bids, "amount_cents > 0 AND amount_cents <= 9007199254740991 AND currency = 'USD'", name: "svdex_bid_amount"
    add_check_constraint :svdex_offering_bids, "char_length(btrim(proposed_terms)) BETWEEN 1 AND 2000", name: "svdex_bid_terms"
  end
end
