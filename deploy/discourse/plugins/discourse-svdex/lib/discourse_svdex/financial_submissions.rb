# frozen_string_literal: true
module DiscourseSvdex
  # Shared validation and visibility for indications, bids and owner history.
  # Consent, aggregation and record ownership remain specific to each workflow.
  module FinancialSubmissions
    MAX_AMOUNT_CENTS = 9_007_199_254_740_991

    def self.amount_cents!(amount, currency:)
      unless amount.is_a?(String) && amount.match?(/\A(?:0|[1-9]\d{0,13})(?:\.\d{1,2})?\z/)
        raise Discourse::InvalidParameters.new(:amount)
      end
      cents = (BigDecimal(amount) * 100).to_i
      raise Discourse::InvalidParameters.new(:amount) unless cents.between?(1, MAX_AMOUNT_CENTS)
      raise Discourse::InvalidParameters.new(:currency) unless currency == "USD"
      cents
    end

    def self.visible_organization?(organization, guardian)
      !!(organization && organization.active? && CompanyDirectory.company?(organization) && guardian.can_see_profile?(organization))
    end

    def self.visible_offering?(topic, guardian)
      !!(topic && !topic.deleted_at && !topic.first_post&.hidden && DiscourseSvdex.listing?(topic) && guardian.can_see?(topic))
    end

    def self.issuer_matches?(topic, organization, guardian)
      visible_organization?(organization, guardian) && visible_offering?(topic, guardian) &&
        CompanyDirectory.interest_organization(topic, guardian)&.fetch(:id) == organization.id
    end

    def self.state(row, now: Time.current)
      row.withdrawn_at ? "withdrawn" : row.expires_at > now ? "current" : "expired"
    end
  end
end
