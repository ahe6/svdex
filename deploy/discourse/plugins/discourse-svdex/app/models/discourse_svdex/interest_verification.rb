# frozen_string_literal: true
module DiscourseSvdex
  # Private, dated capacity reviews. Not accreditation, reserved cash or a bid.
  # Replacement reviews append history; revoking one never revives an older cap.
  class InterestVerification < ActiveRecord::Base
    self.table_name = "svdex_interest_verifications"
    belongs_to :user
    belongs_to :reviewer, class_name: "User", optional: true
    belongs_to :revoked_by, class_name: "User", optional: true
    attr_readonly :user_id, :side, :target_type, :target_id, :amount_cents, :currency, :checked_on, :expires_on, :reviewer_id, :original_reviewer_id, :evidence_reference, :holding_details
    validates :side, inclusion: { in: %w[buy sell] }
    validates :currency, inclusion: { in: ["USD"] }
    validates :amount_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: FinancialSubmissions::MAX_AMOUNT_CENTS }
    validates :evidence_reference, presence: true, length: { maximum: 1000 }
    validates :holding_details, length: { maximum: 500 }

    def self.target_for(row)
      row.respond_to?(:company_profile_id) && row.company_profile_id ? ["company", row.company_profile_id] : ["account", row.organization_id]
    end
    def self.scope_for(user_id, side, type = nil, id = nil)
      where(user_id: user_id, side: side, target_type: side == "sell" ? type : nil, target_id: side == "sell" ? id : nil)
    end
    def self.record!(user, actor:, side:, amount:, checked_on:, expires_on:, evidence_reference:, target_type: nil, target_id: nil, holding_details: nil)
      raise Discourse::InvalidAccess unless actor&.staff?
      raise Discourse::InvalidParameters.new(:side) unless %w[buy sell].include?(side)
      raise Discourse::InvalidParameters.new(:evidence_reference) unless evidence_reference.to_s.strip.length.between?(3, 1000)
      cents = FinancialSubmissions.amount_cents!(amount, currency: "USD")
      begin
        checked, expires = Date.iso8601(checked_on.to_s), Date.iso8601(expires_on.to_s)
      rescue ArgumentError
        raise Discourse::InvalidParameters.new(:dates)
      end
      unless checked <= Date.current && expires >= Date.current && expires >= checked && expires <= checked + 365
        raise Discourse::InvalidParameters.new("Use a past/current check date and an expiry within one year of it")
      end
      if side == "sell"
        raise Discourse::InvalidParameters.new(:target_id) unless target_id.to_s.match?(/\A[1-9]\d*\z/)
        target_id = target_id.to_i
        raise Discourse::InvalidParameters.new(:holding_details) unless holding_details.to_s.strip.length.between?(5, 500)
        target!(target_type, target_id, Guardian.new(actor))
      else
        raise Discourse::InvalidParameters.new(:target) if target_type.present? || target_id.present?
        holding_details = nil
      end
      user.with_lock(requires_new: true) do
        scope_for(user.id, side, target_type, target_id).where(superseded_at: nil).update_all(superseded_at: Time.current, updated_at: Time.current)
        row = create!(user: user, side: side, amount_cents: cents, currency: "USD", target_type: target_type.presence, target_id: target_id.presence,
          checked_on: checked, expires_on: expires, evidence_reference: evidence_reference.to_s.strip, holding_details: holding_details.to_s.strip.presence,
          reviewer: actor, original_reviewer_id: actor.id)
        StaffActionLogger.new(actor).log_custom("svdex_interest_capacity_review", target_user_id: user.id, verification_id: row.id, side: side)
        row
      end
    end
    def self.revoke!(row, actor)
      raise Discourse::InvalidAccess unless actor&.staff?
      row.with_lock do
        unless row.revoked_at
          row.update!(revoked_at: Time.current, revoked_by: actor)
          StaffActionLogger.new(actor).log_custom("svdex_interest_capacity_revoked", target_user_id: row.user_id, verification_id: row.id)
        end
      end
    end
    def self.target!(type, id, guardian)
      if type == "account"
        target = User.find_by(id: id)
        raise Discourse::NotFound unless FinancialSubmissions.visible_organization?(target, guardian)
        { type: type, id: target.id, name: target.name.presence || target.username }
      elsif type == "company" && defined?(Prototypes::CompanyProfileRecord) && Prototypes::CompanyProfileRecord.table_exists?
        target = Prototypes::CompanyProfileRecord.find_by(id: id)
        raise Discourse::NotFound unless Prototypes::CompanyRelationships.visible?(target, guardian)
        { type: type, id: target.id, name: target.name }
      else
        raise Discourse::NotFound
      end
    end
    def self.qualification(row)
      type, id = target_for(row)
      qualification_for(row.user_id, row.side, type, id, amount_cents: row.amount_cents)
    end
    def self.qualification_for(user_id, side, type, id, amount_cents: 0)
      review = scope_for(user_id, side, type, id).where(superseded_at: nil).select(:amount_cents, :checked_on, :expires_on, :revoked_at).first
      return { state: "unverified" } unless review
      state = review.revoked_at ? "revoked" : review.expires_on < Date.current ? "expired" : review.amount_cents < amount_cents ? "above_limit" : "verified"
      { state: state, amount_cents: review.amount_cents, checked_on: review.checked_on, expires_on: review.expires_on }
    end
    def self.covered(scope)
      # Correlated EXISTS prevents duplicate contributions; a partially covered
      # amount is excluded in full, never silently truncated to the review cap.
      matching = "v.target_type = 'account' AND v.target_id = svdex_interest_indications.organization_id"
      if InterestIndication.column_names.include?("company_profile_id")
        matching = "(#{matching}) OR (v.target_type = 'company' AND v.target_id = svdex_interest_indications.company_profile_id)"
      end
      scope.where(<<~SQL)
        EXISTS (SELECT 1 FROM svdex_interest_verifications v
          WHERE v.user_id = svdex_interest_indications.user_id
          AND v.side = svdex_interest_indications.side
          AND v.superseded_at IS NULL AND v.revoked_at IS NULL
          AND v.checked_on <= CURRENT_DATE AND v.expires_on >= CURRENT_DATE
          AND v.amount_cents >= svdex_interest_indications.amount_cents
          AND (v.side = 'buy' OR (#{matching})))
      SQL
    end
    def self.request_review!(row, user)
      raise Discourse::InvalidAccess unless user&.active? && !user.staged? && !user.suspended? && row.user_id == user.id
      raise Discourse::InvalidParameters.new(:interest) unless FinancialSubmissions.state(row) == "current"
      type, id = target_for(row)
      target = target!(type, id, Guardian.new(user))
      # A private-origin offering is never exposed by a general review request.
      if row.topic_id && !FinancialSubmissions.visible_offering?(row.topic, Guardian.new(user))
        raise Discourse::NotFound
      end
      recipient = User.find_by_username(SiteSetting.svdex_private_access_contact)
      raise Discourse::InvalidParameters.new(:reviewer) unless recipient&.active? && recipient.staff?
      amount = ActiveSupport::NumberHelper.number_to_currency(BigDecimal(row.amount_cents.to_s) / 100, precision: 2)
      raw = "Please review my #{row.side == 'buy' ? 'buying capacity' : 'holding and authority to sell'} for my saved **#{amount} USD #{row.side} interest** in **#{target[:name].gsub(/[\[\]*`]/, '')}**.\n\nPlease arrange verification with me privately. This is a nonbinding indication, not an order or investment commitment."
      # Same fixed-recipient intake pattern as native membership requests.
      PostCreator.create!(user, title: "Interest verification: #{target[:name]}", raw: raw, archetype: Archetype.private_message,
        target_usernames: recipient.username, skip_validations: true).topic
    end
  end
end
