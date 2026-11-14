# frozen_string_literal: true
module DiscourseSvdex
  # An owner's management view, never a public activity stream or staff search.
  class MyInterestController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action { response.headers["Cache-Control"] = "private, no-store" }
    PAGE_SIZE = 25
    KINDS = { "interest" => InterestIndication, "bid" => OfferingBid }.freeze

    def index
      kind = params[:kind].presence || "all"
      status = params[:status].presence || "all"
      page = params[:page].presence || "0"
      raise Discourse::InvalidParameters.new(:kind) unless ["all", *KINDS.keys].include?(kind)
      raise Discourse::InvalidParameters.new(:status) unless %w[all current expired withdrawn].include?(status)
      raise Discourse::InvalidParameters.new(:page) unless page.to_s.match?(/\A\d{1,5}\z/) && page.to_i <= 1000
      now = Time.current
      queries = KINDS.filter_map do |key, model|
        next unless kind == "all" || kind == key
        scope = model.where(user: current_user)
        scope = case status
        when "current" then scope.where(withdrawn_at: nil).where("expires_at > ?", now)
        when "expired" then scope.where(withdrawn_at: nil).where("expires_at <= ?", now)
        when "withdrawn" then scope.where.not(withdrawn_at: nil)
        else scope
        end
        scope.select("'#{key}' AS kind", :id, :updated_at).to_sql
      end
      sql = "SELECT * FROM (#{queries.join(' UNION ALL ')}) submissions ORDER BY updated_at DESC, kind ASC, id DESC LIMIT #{PAGE_SIZE + 1} OFFSET #{page.to_i * PAGE_SIZE}"
      refs = ActiveRecord::Base.connection.select_all(sql).to_a
      rows = KINDS.to_h do |key, model|
        ids = refs.select { |ref| ref["kind"] == key }.map { |ref| ref["id"] }
        [key, model.where(user: current_user, id: ids).includes(:organization, topic: :first_post).index_by(&:id)]
      end
      render_json_dump(records: refs.first(PAGE_SIZE).map { |ref| payload(ref["kind"], rows.fetch(ref["kind"]).fetch(ref["id"])) }, has_more: refs.length > PAGE_SIZE)
    end

    def destroy
      RateLimiter.new(current_user, "svdex-history-withdraw", 30, 1.minute).performed!
      model = KINDS[params[:kind]]
      raise Discourse::NotFound unless model
      row = model.find_by(id: params[:id], user: current_user)
      raise Discourse::NotFound unless row
      row.update!(withdrawn_at: Time.current) unless row.withdrawn_at
      render_json_dump(success: true)
    end

    private
    def payload(kind, row)
      organization = row.organization
      org_visible = FinancialSubmissions.visible_organization?(organization, guardian)
      topic = row.topic
      topic_visible = FinancialSubmissions.visible_offering?(topic, guardian)
      issuer_matches = topic_visible && FinancialSubmissions.issuer_matches?(topic, organization, guardian)
      accessible = org_visible && (row.topic_id.nil? || (topic_visible && issuer_matches))
      state = FinancialSubmissions.state(row)
      {
        id: row.id, kind: kind, status: state, amount_cents: row.amount_cents, currency: row.currency,
        updated_at: row.updated_at, expires_at: row.expires_at, withdrawn_at: row.withdrawn_at,
        side: kind == "interest" ? row.side : nil, market: kind == "interest" ? row.market : nil,
        organization: accessible ? { id: organization.id, name: organization.name.presence || organization.username, url: "/u/#{organization.username_lower}/summary" } : nil,
        topic: accessible && topic_visible ? { id: topic.id, title: topic.title, url: topic.url } : nil,
        proposed_terms: kind == "bid" && accessible ? row.proposed_terms : nil,
        can_edit: !!(accessible && (kind == "bid" ? SiteSetting.svdex_bids_enabled && !topic.closed && !topic.archived : SiteSetting.svdex_interest_enabled)),
      }
    end
  end
end
