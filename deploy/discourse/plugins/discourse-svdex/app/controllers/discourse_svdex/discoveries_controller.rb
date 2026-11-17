# frozen_string_literal: true
module DiscourseSvdex
  class DiscoveriesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_staff, only: %i[show update]
    def index
      user = User.find_by!(username_lower: params[:username].to_s.downcase)
      page = params[:page].to_s.presence || "0"
      raise Discourse::InvalidParameters.new(:page) unless page.match?(/\A\d{1,5}\z/)
      render_json_dump(Discoveries.history(user, guardian, type: params[:kind].presence, order: params[:order].presence || "newest", page: page.to_i))
    end
    def show
      render_json_dump(admin_payload(entity))
    end
    def update
      user = entity
      values = params.require(:discovery).permit(:provenance, :status, :contributor, :listed_at, :reason).to_h
      Discoveries.record!(user, current_user, values)
      render_json_dump(admin_payload(user))
    end
    private
    def entity
      user = User.find(params[:user_id])
      raise Discourse::NotFound unless Discoveries.kind(user)
      user
    end
    def admin_payload(user)
      row = Discovery.find_by(entity_user_id: user.id, superseded_by_id: nil)
      events = row ? DiscoveryEvent.where(discovery_id: Discovery.where("entity_user_id = ? OR superseded_by_id = ?", user.id, row.id).select(:id)).order(id: :desc).limit(50).map { |event| event.attributes.merge("label" => event.action.humanize) } : []
      { eligible: true, discovery: row && { provenance: row.provenance, status: row.status, contributor: row.contributor&.username, listed_at: row.listed_at&.iso8601,
        original_entity_user_id: row.original_entity_user_id, original_contributor_user_id: row.original_contributor_user_id }, events: events }
    end
  end
end
