# frozen_string_literal: true
module DiscourseSvdex
  class OfferingBid < ActiveRecord::Base
    self.table_name = "svdex_offering_bids"
    belongs_to :user
    belongs_to :organization, class_name: "User"
    belongs_to :topic
    validates :user_id, uniqueness: { scope: :topic_id }
    validates :amount_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: FinancialSubmissions::MAX_AMOUNT_CENTS }
    validates :currency, inclusion: { in: ["USD"] }
    validates :proposed_terms, presence: true, length: { maximum: 2000 }
    validates :confirmed_at, :expires_at, presence: true
    def active?
      withdrawn_at.nil? && expires_at.future?
    end
  end
end
