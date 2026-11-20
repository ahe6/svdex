# frozen_string_literal: true

require_relative "../../../lib/discourse_svdex/catalog_proposals"

module DiscourseSvdex
  class CatalogProposalsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action do
      response.headers["Cache-Control"] = "private, no-store"
      raise Discourse::NotFound unless CatalogProposals.enabled?
    end

    rescue_from Prototypes::CatalogDocument::Invalid do |error|
      render_json_error(error.message, status: :unprocessable_entity)
    end
    rescue_from CatalogProposals::Conflict do |error|
      render_json_error(error.message, status: :conflict)
    end
    rescue_from CatalogGithub::Unavailable do
      render_json_error("GitHub could not complete the request. You can retry or continue on GitHub.", status: :bad_gateway)
    end

    def show
      RateLimiter.new(current_user, "svdex-catalog-draft", 30, 1.hour).performed!
      draft = proposals.draft(params[:id])
      raise Discourse::NotFound unless draft
      render_json_dump(draft)
    end

    def create
      limit_submission!
      render json: proposals.submit(params[:document]), status: :created
    end

    def update
      limit_submission!
      render json: proposals.submit(params[:document], id: params[:id], sha: params[:sha]), status: :created
    end

    private

    def proposals
      CatalogProposals.new(params[:kind])
    end

    def limit_submission!
      RateLimiter.new(current_user, "svdex-catalog-proposal", 6, 1.hour, apply_limit_to_staff: true).performed!
      RateLimiter.new(nil, "svdex-catalog-proposals", 40, 1.hour).performed!
    end
  end
end
