# frozen_string_literal: true
# name: discourse-svdex
# about: Company profiles and offerings built on native Discourse topics.
# version: 0.3.0
# authors: SVDEX

%w[compass shield-halved key file-lines].each { |icon| register_svg_icon(icon) }

module ::DiscourseSvdex
  PLUGIN_NAME = "discourse-svdex"
  COMPANY_NAME_SQL = "btrim(split_part(topics.title, ' — ', 1))"
  VALUATION_FIELD = "svdex_post_money_valuation_usd"
  MAX_VALUATION = 9_007_199_254_740_991
  INSTRUMENT_TYPES = %w[equity safe convertible_note debt warrant other].freeze
  FIELDS = { "svdex_instrument_type" => 24, "svdex_summary" => 180, "svdex_terms" => 120,
             "svdex_valuation_cap" => 80, "svdex_conversion_discount" => 80, "svdex_strike_price" => 80, "svdex_expiration" => 80,
             "svdex_interest_rate" => 80, "svdex_offering_size" => 80, "svdex_funds_raised" => 80, "svdex_total_funding" => 80, "svdex_minimum" => 80, VALUATION_FIELD => 16 }.freeze

  def self.offering_category_ids
    [SiteSetting.svdex_listings_category_id.to_i, SiteSetting.svdex_public_offerings_category_id.to_i, SiteSetting.svdex_private_offerings_category_id.to_i].select(&:positive?).uniq
  end

  def self.home_category_ids
    (offering_category_ids + [SiteSetting.svdex_introductions_category_id.to_i]).select(&:positive?).uniq
  end

  def self.offering_category?(id)
    offering_category_ids.include?(id.to_i)
  end

  def self.listing?(topic)
    offering_category?(topic.category_id) && topic.archetype == Archetype.default
  end

  # Category-list filters use space-separated tags; core's tag controller
  # otherwise treats that same UI query as a single tag name. Normalize only
  # tag-scoped Offerings, leaving core permission checks and other tags intact.
  module OfferingTagParams
    private

    def tag_params
      names = super
      id = SiteSetting.svdex_listings_category_id.to_i
      if DiscourseSvdex.offering_category?(@filter_on_category&.id) && params[:tags].is_a?(String)
        names.flat_map { |name| name.split(/\s+/) }.uniq
      else
        names
      end
    end
  end

  def self.validate_field!(name, value)
    if name == "svdex_instrument_type"
      raise Discourse::InvalidParameters.new(name) unless value.is_a?(String) && (value.empty? || INSTRUMENT_TYPES.include?(value))
      return value
    end
    if name == VALUATION_FIELD
      return nil if value == ""
      unless (value.is_a?(Integer) || (value.is_a?(String) && value.match?(/\A[0-9]{1,16}\z/))) &&
             value.to_i.between?(1, MAX_VALUATION)
        raise Discourse::InvalidParameters.new(name)
      end
      return value.to_i
    end
    unless value.is_a?(String) && value.length <= FIELDS.fetch(name)
      raise Discourse::InvalidParameters.new(name)
    end
    value.strip
  end
end
require_relative "lib/discourse_svdex/financial_submissions"
require_relative "lib/discourse_svdex/engine"

after_initialize do
  require_relative "lib/discourse_svdex/retired_information_pages"
  AboutController.prepend(DiscourseSvdex::RetiredAboutPage)
  StaticController.prepend(DiscourseSvdex::RetiredGuidelinesPages)
  require_relative "lib/discourse_svdex/company_directory"
  require_relative "lib/discourse_svdex/offering_structure"
  on(:topic_created) { |topic, *_args| DiscourseSvdex::OfferingStructure.sync_visibility!(topic) }
  on(:approved_post) { |_reviewable, post| DiscourseSvdex::OfferingStructure.sync_visibility!(post.topic) }
  on(:topic_category_changed) { |topic, *_args| DiscourseSvdex::OfferingStructure.sync_visibility!(topic) }
  on(:topic_tags_changed) { |topic, *_args| DiscourseSvdex::OfferingStructure.sync_visibility!(topic) }
  require_relative "app/models/discourse_svdex/offering_bid"
  require_relative "app/controllers/discourse_svdex/offering_bids_controller"
  require_relative "app/models/discourse_svdex/interest_indication"
  require_relative "app/controllers/discourse_svdex/interests_controller"
  require_relative "app/controllers/discourse_svdex/my_interest_controller"
  require_relative "app/controllers/discourse_svdex/company_details_controller"
  require_relative "app/controllers/discourse_svdex/company_directory_controller"
  require_relative "app/controllers/discourse_svdex/private_access_controller"
  User.class_eval { attr_accessor :svdex_company_directory_details }
  DirectoryItem.class_eval { attr_accessor :svdex_organizations }
  add_to_serializer(:directory_item, :svdex_organizations) { object.svdex_organizations || 0 }
  DiscourseSvdex::CompanyDirectory::FIELDS.each do |key, field|
    register_user_custom_field_type(field, DiscourseSvdex::CompanyDirectory::METADATA_TYPES[key] || (%w[stage headquarters_country].include?(key) ? :string : :integer))
  end
  Guardian.prepend(DiscourseSvdex::CompanyDirectory::ProfileVisibility)
  DirectoryItemsQuery.prepend(DiscourseSvdex::CompanyDirectory::Query)
  add_to_serializer(:user_name, :svdex_company, include_condition: -> {
    object.is_a?(User) && object.svdex_company_directory_details && scope.public_can_see_profiles? && scope.can_see_profile?(object)
  }) { object.svdex_company_directory_details }
  add_to_serializer(:user, :svdex_company_account, include_condition: -> {
    object.is_a?(User) && scope.can_see_profile?(object) && DiscourseSvdex::CompanyDirectory.company?(object) && scope.can_see_group_and_members?(Group.find_by(name: SiteSetting.svdex_companies_group_name))
  }) { true }
  add_to_serializer(:admin_detailed_user, :svdex_company_account) { DiscourseSvdex::CompanyDirectory.company?(object) }
  TagsController.prepend(DiscourseSvdex::OfferingTagParams)
  on(:user_added_to_group) do |user, group|
    if group.name == SiteSetting.svdex_private_offerings_group_name
      badge = Badge.find_by(name: "Private Access")
      BadgeGranter.grant(badge, user) if badge&.enabled?
    end
  end
  on(:user_removed_from_group) do |user, group|
    if group.name == SiteSetting.svdex_private_offerings_group_name
      badge = Badge.find_by(name: "Private Access")
      UserBadge.where(badge: badge, user: user).find_each { |grant| BadgeGranter.revoke(grant) } if badge
    end
  end
  # Home is a discovery feed for offerings and approved company/fund updates,
  # including introductions. Discussions and Help remain readable in their own
  # categories, search, bookmarks, notifications and direct links. Apply the
  # allowlist before pagination rather than hiding fetched topics in the UI.
  # Native Guardian filtering still protects private offering categories.
  register_modifier(:topic_query_create_list_topics) do |topics, options, query|
    opts = query.options.merge(options)
    scoped = %i[category category_id tags tag_id username group_name topic_ids].any? { |key| opts[key].present? }
    if %w[latest top].include?(opts[:filter].to_s) && !scoped
      topics.where(category_id: DiscourseSvdex.home_category_ids)
        .where.not(id: Category.where(id: DiscourseSvdex.home_category_ids).where.not(topic_id: nil).select(:topic_id))
    else
      topics
    end
  end

  # Native filtering/Guardian scoping runs before this modifier. The window
  # count sees all matching rows before LIMIT/OFFSET, without a second request.
  register_modifier(:topic_query_create_list_topics) do |topics, options, query|
    if DiscourseSvdex.offering_category?(query.options.merge(options)[:category_id])
      topics = topics.select("topics.*") if topics.select_values.empty?
      topics.select("COUNT(*) OVER() AS svdex_offering_count")
    else
      topics
    end
  end
  add_to_serializer(:topic_list, :svdex_offering_count, include_condition: -> {
    DiscourseSvdex.offering_category?(object.category&.id)
  }) { object.topics.first&.attributes&.fetch("svdex_offering_count", 0).to_i }

  DiscourseSvdex::FIELDS.each do |name, length|
    register_topic_custom_field_type(name, name == DiscourseSvdex::VALUATION_FIELD ? :integer : :string, max_length: length)
    add_permitted_post_create_param(name.to_sym)
    # Keep structured listing fields when core queues a topic for approval.
    NewPostManager.add_plugin_payload_attribute(name.to_sym)
    add_permitted_post_update_param(name.to_sym) do |post, value|
      next if value.nil?
      raise Discourse::InvalidParameters.new(name) unless post.is_first_post? && DiscourseSvdex.listing?(post.topic)
      DiscourseSvdex.validate_field!(name, value)
    end
  end

  ReviewableQueuedPostSerializer.payload_attributes(*DiscourseSvdex::FIELDS.keys)

  require_relative "app/controllers/discourse_svdex/listings_controller"
  Discourse::Application.routes.append { mount DiscourseSvdex::Engine, at: "/listings" }

  # The native description topic is category documentation, never a listing,
  # including for staff who can otherwise see unlisted topics.
  # Home's native tag selector narrows the existing feed, not the global tag
  # directory. The marker preserves that allowlist through tag filtering.
  TopicQuery.add_custom_filter(:svdex_home) do |results, query|
    if query.options[:svdex_home].to_s == "1"
      results.where(category_id: DiscourseSvdex.home_category_ids)
        .where.not(id: Category.where(id: DiscourseSvdex.home_category_ids).where.not(topic_id: nil).select(:topic_id))
    else
      results
    end
  end

  TopicQuery.add_custom_filter(:svdex_listing_rows) do |results, query|
    if DiscourseSvdex.offering_category?(query.options[:category_id])
      description_ids = Category.where(id: DiscourseSvdex.offering_category_ids).where.not(topic_id: nil).pluck(:topic_id)
      results.where.not(id: description_ids)
    else
      results
    end
  end

  TopicQuery.add_custom_filter(:svdex_active) do |results, query|
    query.options[:svdex_active].to_s == "1" ? results.where(closed: false, archived: false) : results
  end

  TopicQuery.add_custom_filter(:svdex_company) do |results, query|
    value = query.options[:svdex_company]
    if value.present? && DiscourseSvdex.offering_category?(query.options[:category_id])
      raise Discourse::InvalidParameters.new(:svdex_company) unless value.is_a?(String) && value.length <= 120
      company = value.strip.split(" — ", 2).first
      results.where("(#{DiscourseSvdex::COMPANY_NAME_SQL} ILIKE :company OR topics.title ILIKE :offering)",
        company: "%#{ActiveRecord::Base.sanitize_sql_like(company)}%",
        offering: "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%")
    else
      results
    end
  end

  TopicQuery.add_custom_filter(:svdex_valuation) do |results, query|
    value = query.options[:svdex_valuation]
    if value.present? && DiscourseSvdex.offering_category?(query.options[:category_id])
      ranges = { "under-10m" => [1, 10_000_000], "10m-50m" => [10_000_000, 50_000_000],
                 "50m-250m" => [50_000_000, 250_000_000], "250m-plus" => [250_000_000, nil] }
      raise Discourse::InvalidParameters.new(:svdex_valuation) unless ranges.key?(value) || value == "undisclosed"
      amount = "CASE WHEN value ~ '^[0-9]+$' THEN value::numeric ELSE NULL END"
      known = TopicCustomField.where(name: DiscourseSvdex::VALUATION_FIELD).where("#{amount} > 0")
      if value == "undisclosed"
        results.where.not(id: known.select(:topic_id))
      else
        lower, upper = ranges.fetch(value)
        matching = known.where("#{amount} >= ?", lower)
        matching = matching.where("#{amount} < ?", upper) if upper
        results.where(id: matching.select(:topic_id))
      end
    else
      results
    end
  end

  DiscourseSvdex::FIELDS.each_key do |name|
    add_preloaded_topic_list_custom_field(name)
    PostRevisor.track_topic_field(name.to_sym) do |changes, value|
      next if value.nil? || !DiscourseSvdex.listing?(changes.topic)
      value = DiscourseSvdex.validate_field!(name, value)
      changes.record_change(name, changes.topic.custom_fields[name], value)
      changes.topic.custom_fields[name] = value
    end
  end

  on(:before_create_topic) do |topic, creator|
    supplied = DiscourseSvdex::FIELDS.keys.select { |key| creator.opts.key?(key.to_sym) }
    if supplied.any? && !DiscourseSvdex.listing?(topic)
      raise Discourse::InvalidParameters.new(:category)
    end
    supplied.each do |key|
      topic.custom_fields[key] = DiscourseSvdex.validate_field!(key, creator.opts[key.to_sym])
    end
  end

  # Available only when core has already authorized the topic/list response.
  [:topic_list_item, :topic_view].each do |serializer|
    add_to_serializer(serializer, :svdex_listing, include_condition: -> {
      DiscourseSvdex.listing?(object.respond_to?(:topic) ? object.topic : object)
    }) do
      topic = object.respond_to?(:topic) ? object.topic : object
      values = DiscourseSvdex::FIELDS.keys.to_h { |key| [key.delete_prefix("svdex_"), topic.custom_fields[key].to_s] }
      company_group = TagGroup.find_by_name_insensitive("Companies")
      company_ids = company_group ? DiscourseTagging.visible_tags(scope).where(id: company_group.tags.select(:id)).pluck(:id) : []
      values["company_tag_ids"] = topic.tags.map(&:id) & company_ids
      if serializer == :topic_view && (SiteSetting.svdex_interest_enabled || SiteSetting.svdex_bids_enabled)
        values["interest_organization"] = DiscourseSvdex::CompanyDirectory.interest_organization(topic, scope)
        if values["interest_organization"] && DiscourseSvdex::InterestIndication.totals_visible?(scope)
          organization_id = values["interest_organization"][:id]
          values["interest_totals"] = DiscourseSvdex::InterestIndication.offering_totals(organization_id, topic, scope)
        end
      end
      values
    end
  end

  # DirectoryItemSerializer::UserSerializer inherits this native serializer.
  # Only marked company accounts expose a public biography summary. Core still
  # handles directory group visibility and profile privacy.
  add_to_serializer(:user_name, :svdex_company_summary, include_condition: -> {
    object.is_a?(User) && scope.public_can_see_profiles? && scope.can_see_profile?(object) &&
      DiscourseSvdex::CompanyDirectory.company?(object)
  }) do
    ActionView::Base.full_sanitizer.sanitize(object.user_profile.bio_excerpt.to_s).strip
  end

  Discourse::Application.routes.append do
    get "/private-offerings/summary", to: "discourse_svdex/private_access#summary", defaults: { format: :json }
    get "/private-offerings", to: "discourse_svdex/private_access#index", constraints: { format: "html" }
    get "/companies", to: "users#index", constraints: { format: "html" }
    get "/all-forums", to: "categories#index", constraints: { format: "html" }
    get "/discussion-forums", to: "categories#index", constraints: { format: "html" }
  end
end
