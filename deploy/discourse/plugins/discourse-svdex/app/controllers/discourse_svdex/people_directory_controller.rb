# frozen_string_literal: true
module DiscourseSvdex
  # Reuse native directory querying/serialization, with a fixed curated scope.
  # The native /directory_items endpoint remains the participating Users directory.
  class PeopleDirectoryController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      raise Discourse::InvalidAccess unless SiteSetting.enable_user_directory?
      guardian.ensure_public_can_see_profiles!
      page = fetch_int_from_params(:page, default: 0, max: DirectoryItemsQuery::PAGE_LIMIT)
      limit = fetch_limit_from_params(default: DirectoryItemsQuery::PAGE_SIZE, max: DirectoryItemsQuery::PAGE_SIZE)
      filters = PeopleDirectory.validate_filters!(params.permit(*PeopleDirectory::FILTER_KEYS).to_h)
      result = DirectoryItemsQuery.new(user: current_user, guardian: guardian).call(
        period_type: DirectoryItem.period_types[:all], group_name: SiteSetting.svdex_people_group_name,
        svdex_catalog: "people", svdex_people_filters: filters, name: params[:name], username: params[:username], order: "username",
        ascending: params[:asc].present?, page: page, limit: limit, prioritize_user: false,
      )
      more = params.permit(:name, :username, :asc, *PeopleDirectory::FILTER_KEYS).to_h.merge(page: page + 1, limit: limit)
      choices = PeopleDirectory.filter_options(guardian)
      render_json_dump(directory_items: serialize_data(result.items, DirectoryItemSerializer, attributes: result.active_column_names),
        meta: { organizations: choices[:organizations], locations: choices[:locations], last_updated_at: result.last_updated_at, total_rows_directory_items: result.total,
          load_more_directory_items: "/people/directory_items.json?#{more.to_query}" })
    rescue DirectoryItemsQuery::GroupNotFound
      raise Discourse::InvalidParameters.new(:group)
    end
  end
end
