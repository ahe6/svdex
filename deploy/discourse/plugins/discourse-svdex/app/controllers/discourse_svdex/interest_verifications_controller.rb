# frozen_string_literal: true
module DiscourseSvdex
  class InterestVerificationsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action :ensure_staff, except: :request_review
    before_action { response.headers["Cache-Control"] = "private, no-store" }

    def index
      user = User.find(params[:user_id])
      render_json_dump(records: serialize_reviews(user))
    end
    def create
      RateLimiter.new(current_user, "svdex-capacity-review", 30, 1.minute).performed!
      user = User.find(params[:user_id])
      data = params.require(:verification).permit(:side, :amount, :checked_on, :expires_on, :evidence_reference, :target_type, :target_id, :holding_details).to_h.symbolize_keys
      %i[side amount checked_on expires_on evidence_reference].each { |key| raise Discourse::InvalidParameters.new(key) unless data.key?(key) }
      InterestVerification.record!(user, actor: current_user, **data)
      render_json_dump(records: serialize_reviews(user))
    end
    def destroy
      row = InterestVerification.find(params[:id])
      InterestVerification.revoke!(row, current_user)
      render_json_dump(success: true)
    end
    def request_review
      raise Discourse::NotFound unless SiteSetting.svdex_interest_enabled
      RateLimiter.new(current_user, "svdex-capacity-request", 5, 1.day).performed!
      row = InterestIndication.find_by!(id: params[:id], user: current_user)
      topic = InterestVerification.request_review!(row, current_user)
      render_json_dump(url: topic.relative_url)
    end
    def targets
      query = params[:name].to_s.strip.first(100)
      group_names = [SiteSetting.svdex_companies_group_name, SiteSetting.svdex_funds_group_name]
      users = User.joins(:groups).where(groups: { name: group_names }, active: true, staged: false, admin: false, moderator: false)
      if query.present?
        escaped = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        users = users.where("users.name ILIKE ? OR users.username ILIKE ?", escaped, escaped)
      end
      rows = users.distinct.order(:username).limit(25).filter_map do |user|
        next unless FinancialSubmissions.visible_organization?(user, guardian)
        { id: "account:#{user.id}", name: "#{user.name.presence || user.username} · @#{user.username}", target_type: "account", target_id: user.id }
      end
      if defined?(Prototypes::CompanyProfileRecord) && Prototypes::CompanyProfileRecord.table_exists?
        records = Prototypes::CompanyProfileRecord.order(:name)
        records = records.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%") if query.present?
        rows.concat(records.limit(25).map { |record| { id: "company:#{record.id}", name: record.name, target_type: "company", target_id: record.id } })
      end
      render_json_dump(targets: rows.sort_by { |row| row[:name] })
    end
    private
    def serialize_reviews(user)
      InterestVerification.where(user: user).includes(:reviewer, :revoked_by).order(id: :desc).limit(50).map do |row|
        target = begin
          InterestVerification.target!(row.target_type, row.target_id, guardian) if row.side == "sell"
        rescue Discourse::NotFound
          nil
        end
        row.attributes.slice("id", "side", "amount_cents", "currency", "checked_on", "expires_on", "evidence_reference", "holding_details", "superseded_at", "revoked_at", "created_at")
          .merge(target: target, reviewer: row.reviewer&.username, revoked_by: row.revoked_by&.username)
      end
    end
  end
end
