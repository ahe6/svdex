# frozen_string_literal: true
module DiscourseSvdex
  class CompanyDirectoryController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      raise Discourse::InvalidAccess unless SiteSetting.enable_user_directory?
      page = fetch_int_from_params(:page, default: 0, max: DirectoryItemsQuery::PAGE_LIMIT)
      limit = fetch_limit_from_params(default: DirectoryItemsQuery::PAGE_SIZE, max: DirectoryItemsQuery::PAGE_SIZE)
      filters = CompanyDirectory.validate_filters!(params.permit(*CompanyDirectory::FILTER_KEYS).to_h)
      if filters["svdex_sector"] && CompanyDirectory.tag_options("Sectors", guardian).none? { |tag| tag[:id] == filters["svdex_sector"] }
        raise Discourse::InvalidParameters.new(:svdex_sector)
      end
      kind = params[:kind].presence || "companies"
      raise Discourse::InvalidParameters.new(:kind) unless %w[all companies funds].include?(kind)
      filters["kind"] = kind
      order = %w[username svdex_total_funding svdex_last_valuation svdex_fund_size svdex_aum svdex_buy_interest svdex_sell_interest].include?(params[:order]) ? params[:order] : "svdex_total_funding"
      result = DirectoryItemsQuery.new(user: current_user, guardian: guardian).call(
        period_type: DirectoryItem.period_types[:all], group_name: SiteSetting.svdex_companies_group_name,
        name: params[:name], order: order, ascending: params[:asc].present?,
        page: page, limit: limit, prioritize_user: false, svdex_catalog: "companies", svdex_filters: filters,
      )
      more = params.permit(:kind, :name, :order, :asc, *CompanyDirectory::FILTER_KEYS).to_h.merge(page: page + 1, limit: limit)
      render_json_dump(
        directory_items: serialize_data(result.items, DirectoryItemSerializer, attributes: result.active_column_names),
        meta: {
          last_updated_at: result.last_updated_at,
          total_rows_directory_items: result.total,
          load_more_directory_items: "/listings/company-directory.json?#{more.to_query}",
          sectors: CompanyDirectory.tag_options("Sectors", guardian),
          stages: CompanyDirectory::STAGES,
          locations: CompanyDirectory.location_options(guardian),
        },
      )
    rescue DirectoryItemsQuery::GroupNotFound
      raise Discourse::InvalidParameters.new(:group)
    end

    def profile
      guardian.ensure_public_can_see_profiles!
      user = User.find_by_username(params[:username])
      raise Discourse::NotFound unless user && CompanyDirectory.company?(user) && guardian.can_see_profile?(user)
      guardian.ensure_can_see_group_and_members!(Group.find_by!(name: SiteSetting.svdex_companies_group_name))
      CompanyDirectory.populate([user], guardian)
      company = user.svdex_company_directory_details
      topics = company[:company_tag] ? CompanyDirectory.offering_scope(guardian).joins(:tags).where(tags: { id: company[:company_tag][:id] }).order(created_at: :desc).limit(6) : []
      updates_category = Category.find_by(id: SiteSetting.svdex_introductions_category_id)
      updates_category = nil unless updates_category && guardian.can_see?(updates_category)
      updates = if updates_category && company[:company_tag]
        Topic.visible.secured(guardian).listable_topics.where(category_id: updates_category.id, archetype: Archetype.default)
          .where.not(id: updates_category.topic_id).joins(:tags).where(tags: { id: company[:company_tag][:id] }).order(created_at: :desc).limit(6)
      else
        []
      end
      summary = ->(topic) { { id: topic.id, title: topic.title, fancyTitle: topic.fancy_title, url: topic.url, created_at: topic.created_at, like_count: topic.like_count } }
      render_json_dump(company: company, offerings: topics.map(&summary), updates: updates.map(&summary),
        updates_url: updates_category && company[:company_tag] ? "/tags#{updates_category.url}/#{company[:company_tag][:slug]}/#{company[:company_tag][:id]}" : nil)
    end
  end
end
