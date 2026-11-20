# frozen_string_literal: true
module DiscourseSvdex
  class InterestsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action { response.headers["Cache-Control"] = "private, no-store" }
    before_action { raise Discourse::NotFound unless SiteSetting.svdex_interest_enabled || action_name == "destroy" }

    def index
      organization = organization!
      mine = target_scope(organization).where(user: current_user).order(:side)
      # Individual records remain self/staff-only, irrespective of public aggregates.
      rows = InterestIndication.preview?(guardian) ? target_scope(organization).merge(InterestIndication.disclosed_to(guardian)).includes(:user).order(updated_at: :desc).limit(100) : mine
      response = { interest: mine.map { |row| payload(row) }, records: rows.map { |row| payload(row, staff: InterestIndication.preview?(guardian)) }, totals: target_totals(organization) }
      type, id = verification_target(organization)
      response[:capacity] = %w[buy sell].to_h { |side| [side, InterestVerification.qualification_for(current_user.id, side, type, id)] }
      response[:verification_documents_ready] = InterestVerification.document_uploads_ready?
      if params[:topic_id].present?
        topic = offering!(organization, params[:topic_id])
        response[:offering_totals] = InterestIndication.offering_totals(organization.id, topic, guardian)
      end
      render_json_dump(response)
    end

    def update
      RateLimiter.new(current_user, "svdex-interest-write", 30, 1.minute).performed!
      organization = organization!
      side = params[:side].to_s
      raise Discourse::InvalidParameters.new(:side) unless %w[buy sell].include?(side)
      data = params.require(:interest).permit(:amount, :currency, :market, :topic_id, :confirmation).to_h
      raise Discourse::InvalidParameters.new(:confirmation) unless %w[nonbinding nonbinding-public-v1].include?(data["confirmation"])
      cents = FinancialSubmissions.amount_cents!(data["amount"], currency: data["currency"])
      topic = data["topic_id"].present? ? offering!(organization, data["topic_id"]) : nil
      # One current indication per investor/entity/side. Linking an offering
      # replaces that same record, rather than counting it a second time.
      current_user.with_lock do
        row = target_scope(organization).find_or_initialize_by(user: current_user, side: side)
        row.assign_attributes(amount_cents: cents, currency: "USD", market: data["market"], topic: topic,
          source_was_restricted: row.source_was_restricted || topic&.category&.read_restricted? || false,
          aggregate_consent_at: data["confirmation"] == "nonbinding-public-v1" ? Time.current : nil,
          withdrawn_at: nil, expires_at: 30.days.from_now)
        raise Discourse::InvalidParameters.new(:interest) unless row.save
        render_json_dump(interest: payload(row))
      end
    end

    def destroy
      # Withdrawal remains possible after an offering/profile becomes unavailable.
      row = InterestIndication.find_by(user: current_user, organization_id: params[:organization_id], side: params[:side])
      raise Discourse::NotFound unless row
      row.update!(withdrawn_at: Time.current)
      render_json_dump(success: true)
    end

    private
    def verification_target(organization)
      ["account", organization.id]
    end

    def target_scope(organization)
      InterestIndication.where(organization_id: organization.id)
    end

    def target_totals(organization)
      InterestIndication.totals([organization.id], guardian)[organization.id]
    end

    def offering!(organization, id)
      topic = Topic.find_by(id: id)
      raise Discourse::NotFound unless FinancialSubmissions.visible_offering?(topic, guardian)
      tag_id = organization.custom_fields[CompanyDirectory::FIELDS.fetch("company_tag_id")]
      raise Discourse::InvalidParameters.new(:topic_id) unless tag_id.present? && topic.tags.exists?(id: tag_id)
      topic
    end

    def organization!
      organization = User.find_by(id: params[:organization_id])
      raise Discourse::NotFound unless FinancialSubmissions.visible_organization?(organization, guardian)
      organization
    end
    def payload(row, staff: false)
      # Do not return restricted opportunity identities after access is lost.
      visible = row.topic_id.nil? || FinancialSubmissions.visible_offering?(row.topic, guardian)
      { id: row.id, side: row.side, market: row.market, currency: "USD", amount_cents: row.amount_cents,
        expires_at: row.expires_at, updated_at: row.updated_at, withdrawn_at: row.withdrawn_at,
        public_aggregate_consent: row.aggregate_consent_at.present?,
        verification: InterestVerification.qualification(row),
        active: FinancialSubmissions.state(row) == "current", topic_id: visible ? row.topic_id : nil,
        username: staff ? row.user.username : nil }
    end
  end
end
