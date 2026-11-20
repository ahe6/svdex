# frozen_string_literal: true
module DiscourseSvdex
  class InterestIndication < ActiveRecord::Base
    self.table_name = "svdex_interest_indications"
    belongs_to :user
    belongs_to :organization, class_name: "User", optional: true
    validate { errors.add(:organization, "must exist") unless organization || (respond_to?(:company_profile_id) && company_profile_id.present?) }
    belongs_to :topic, optional: true
    validates :side, inclusion: { in: %w[buy sell] }
    validates :market, inclusion: { in: %w[primary secondary either] }
    validates :currency, inclusion: { in: ["USD"] }
    validates :amount_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: FinancialSubmissions::MAX_AMOUNT_CENTS }
    validates :expires_at, presence: true
    validates :user_id, uniqueness: { scope: [:organization_id, :side] }, if: -> { organization_id.present? }
    validate { errors.add(:market, "must be secondary for a sale") if side == "sell" && market != "secondary" }

    def self.preview?(guardian)
      SiteSetting.svdex_interest_enabled && SiteSetting.svdex_interest_staff_preview && guardian.is_staff?
    end

    def self.disclosed_to(guardian)
      return none unless preview?(guardian)
      allowed = CompanyDirectory.offering_scope(guardian).select(:id)
      where("(topic_id IS NULL AND NOT source_was_restricted) OR topic_id IN (?)", allowed)
    end

    def self.public_totals?
      SiteSetting.svdex_interest_enabled && SiteSetting.svdex_interest_public_totals
    end

    def self.totals_visible?(guardian)
      public_totals? || preview?(guardian)
    end

    def self.aggregate_scope(guardian)
      return disclosed_to(guardian) unless public_totals?
      public_topics = CompanyDirectory.offering_scope(Guardian.new).select(:id)
      InterestVerification.covered(where.not(aggregate_consent_at: nil).where(source_was_restricted: false)
        .where("topic_id IS NULL OR topic_id IN (?)", public_topics))
    end

    def self.totals(organization_ids, guardian)
      return {} unless totals_visible?(guardian)
      aggregate_scope(guardian).where(organization_id: organization_ids).group(:organization_id, :side)
        .pluck(:organization_id, :side, Arel.sql("COALESCE(SUM(CASE WHEN withdrawn_at IS NULL AND expires_at > CURRENT_TIMESTAMP THEN amount_cents ELSE 0 END), 0)"))
        .each_with_object({}) { |(id, side, cents), result| (result[id] ||= {})[side] = cents.to_i }
    end

    # Narrow the existing disclosure scope; an offering must never inherit
    # unrelated company interest or bypass restricted-origin exclusions.
    def self.offering_totals(organization_id, topic, guardian)
      return {} unless totals_visible?(guardian) && guardian.can_see?(topic)
      aggregate_scope(guardian).where(organization_id: organization_id, topic_id: topic.id).group(:side)
        .pluck(:side, Arel.sql("COALESCE(SUM(CASE WHEN withdrawn_at IS NULL AND expires_at > CURRENT_TIMESTAMP THEN amount_cents ELSE 0 END), 0)"))
        .to_h.transform_values(&:to_i)
    end

    def self.aggregate_amounts(side, guardian)
      raise Discourse::InvalidAccess unless totals_visible?(guardian)
      aggregate_scope(guardian).where(side: side).group(:organization_id)
        .select(:organization_id, "SUM(CASE WHEN withdrawn_at IS NULL AND expires_at > CURRENT_TIMESTAMP THEN amount_cents ELSE 0 END) AS total")
    end

    def self.filter_items(items, side, range, guardian)
      amounts = aggregate_amounts(side, guardian)
      table = side == "buy" ? "svdex_buy_filter" : "svdex_sell_filter"
      items = items.joins("LEFT JOIN (#{amounts.to_sql}) #{table} ON #{table}.organization_id = directory_items.user_id")
      return items.where("#{table}.total IS NULL") if range == "undisclosed"
      min, max = CompanyDirectory::RANGES.fetch(range)
      items = items.where("#{table}.total >= ?", min * 100) if min
      items = items.where("#{table}.total < ?", max * 100) if max
      items
    end

    def self.sort_items(items, side, ascending, guardian)
      raise Discourse::InvalidAccess unless totals_visible?(guardian)
      amounts = aggregate_amounts(side, guardian)
      items.joins("LEFT JOIN (#{amounts.to_sql}) svdex_interest_sum ON svdex_interest_sum.organization_id = directory_items.user_id")
        .order(Arel.sql("svdex_interest_sum.total #{ascending ? 'ASC' : 'DESC'} NULLS LAST"), id: :asc)
    end
  end
end
