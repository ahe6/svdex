# frozen_string_literal: true
module DiscourseSvdex
  class OfferingBidsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action { response.headers["Cache-Control"] = "private, no-store" }
    before_action { raise Discourse::NotFound unless SiteSetting.svdex_bids_enabled || action_name == "destroy" }

    def index
      topic, organization = offering!
      mine = OfferingBid.find_by(user: current_user, topic: topic)
      rows = guardian.is_staff? && SiteSetting.svdex_bids_staff_preview ? OfferingBid.where(topic: topic).includes(:user).order(updated_at: :desc).limit(100) : []
      render_json_dump(bid: mine && payload(mine), records: rows.map { |row| payload(row, staff: true) })
    end

    def update
      RateLimiter.new(current_user, "svdex-bid-write", 30, 1.minute).performed!
      topic, organization = offering!
      raise Discourse::InvalidAccess if topic.closed || topic.archived
      data = params.require(:bid).permit(:amount, :currency, :proposed_terms, :confirmation).to_h
      raise Discourse::InvalidParameters.new(:confirmation) unless data["confirmation"] == "nonbinding-bid-v1"
      cents = FinancialSubmissions.amount_cents!(data["amount"], currency: data["currency"])
      terms = data["proposed_terms"]
      raise Discourse::InvalidParameters.new(:proposed_terms) unless terms.is_a?(String) && terms.strip.length.between?(1, 2000)
      current_user.with_lock do
        row = OfferingBid.find_or_initialize_by(user: current_user, topic: topic)
        row.assign_attributes(organization: organization, amount_cents: cents, currency: "USD", proposed_terms: terms.strip,
          confirmed_at: Time.current, expires_at: 30.days.from_now, withdrawn_at: nil)
        raise Discourse::InvalidParameters.new(:bid) unless row.save
        render_json_dump(bid: payload(row))
      end
    end

    def destroy
      # Withdrawal remains available even if the offering or feature is unavailable.
      row = OfferingBid.find_by(user: current_user, topic_id: params[:topic_id])
      raise Discourse::NotFound unless row
      row.update!(withdrawn_at: Time.current)
      render_json_dump(success: true)
    end

    private
    def offering!
      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless FinancialSubmissions.visible_offering?(topic, guardian)
      issuer = CompanyDirectory.interest_organization(topic, guardian)
      raise Discourse::NotFound unless issuer
      [topic, User.find(issuer[:id])]
    end
    def payload(row, staff: false)
      { id: row.id, amount_cents: row.amount_cents, currency: row.currency, proposed_terms: row.proposed_terms,
        active: row.active?, expires_at: row.expires_at, withdrawn_at: row.withdrawn_at, updated_at: row.updated_at,
        username: staff ? row.user.username : nil }
    end
  end
end
