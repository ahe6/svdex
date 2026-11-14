# frozen_string_literal: true
module DiscourseSvdex
  # Compatibility links only: there is no parallel catalog or watchlist API.
  class ListingsController < ::ApplicationController
    skip_before_action :check_xhr
    requires_plugin PLUGIN_NAME
    requires_login only: [:saved]

    def index
      category = Category.find_by(id: SiteSetting.svdex_listings_category_id)
      raise Discourse::NotFound unless category
      guardian.ensure_can_see!(category)
      redirect_to category.url, status: :found
    end

    def companies
      category_id = params[:category_id].presence || SiteSetting.svdex_listings_category_id
      raise Discourse::InvalidParameters.new(:category_id) unless DiscourseSvdex.offering_category?(category_id)
      category = Category.find_by(id: category_id)
      raise Discourse::NotFound unless category
      guardian.ensure_can_see!(category)
      term = params[:q] || ""
      raise Discourse::InvalidParameters.new(:q) unless term.is_a?(String) && term.length <= 120
      return render_json_dump(companies: []) if term.strip.blank?
      company = term.strip.split(" — ", 2).first
      company_name = Arel.sql(DiscourseSvdex::COMPANY_NAME_SQL)
      names = Topic.visible.secured(guardian).listable_topics
        .where(category_id: Category.subcategory_ids(category.id)).where.not(id: Category.where(id: DiscourseSvdex.offering_category_ids).where.not(topic_id: nil).select(:topic_id))
        .where("#{DiscourseSvdex::COMPANY_NAME_SQL} ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(company)}%")
        .distinct.order(company_name).limit(10).pluck(company_name)
      render_json_dump(companies: names.map { |name| { name: name } })
    end

    def saved
      redirect_to "/u/#{current_user.username_lower}/activity/bookmarks", status: :found
    end

    def show
      source = TopicCustomField.find_by(name: "svdex_source_id", value: params[:id])
      topic = source&.topic
      raise Discourse::NotFound unless topic && DiscourseSvdex.listing?(topic)
      guardian.ensure_can_see!(topic)
      redirect_to topic.url, status: :found
    end
  end
end
