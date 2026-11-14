# frozen_string_literal: true
class AddAggregateConsentToSvdexInterestIndications < ActiveRecord::Migration[7.2]
  def change
    # Prior private submissions never become public contributions automatically.
    add_column :svdex_interest_indications, :aggregate_consent_at, :datetime
  end
end
