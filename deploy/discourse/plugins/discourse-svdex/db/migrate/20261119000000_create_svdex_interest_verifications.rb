# frozen_string_literal: true
class CreateSvdexInterestVerifications < ActiveRecord::Migration[7.2]
  def change
    create_table :svdex_interest_verifications do |t|
      t.bigint :user_id, null: false
      t.string :side, null: false
      t.string :target_type
      t.bigint :target_id
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.date :checked_on, null: false
      t.date :expires_on, null: false
      t.bigint :reviewer_id
      t.bigint :original_reviewer_id, null: false
      t.text :evidence_reference, null: false
      t.text :holding_details
      t.datetime :superseded_at
      t.datetime :revoked_at
      t.bigint :revoked_by_id
      t.timestamps null: false
    end
    add_foreign_key :svdex_interest_verifications, :users, on_delete: :cascade
    add_foreign_key :svdex_interest_verifications, :users, column: :reviewer_id, on_delete: :nullify
    add_foreign_key :svdex_interest_verifications, :users, column: :revoked_by_id, on_delete: :nullify
    add_index :svdex_interest_verifications, :user_id, unique: true, where: "side = 'buy' AND superseded_at IS NULL", name: "svdex_current_buy_capacity"
    add_index :svdex_interest_verifications, [:user_id, :target_type, :target_id], unique: true, where: "side = 'sell' AND superseded_at IS NULL", name: "svdex_current_sell_capacity"
    add_check_constraint :svdex_interest_verifications, "amount_cents > 0 AND amount_cents <= 9007199254740991 AND currency = 'USD' AND expires_on >= checked_on", name: "svdex_verification_amount_dates"
    add_check_constraint :svdex_interest_verifications, "(side = 'buy' AND target_type IS NULL AND target_id IS NULL) OR (side = 'sell' AND target_type IN ('account','company') AND target_id IS NOT NULL AND target_id > 0 AND holding_details IS NOT NULL)", name: "svdex_verification_scope"
  end
end
