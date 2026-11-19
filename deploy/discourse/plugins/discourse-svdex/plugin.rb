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
    (offering_category_ids + [SiteSetting.svdex_introductions_category_id.to_i, SiteSetting.svdex_presales_category_id.to_i]).select(&:positive?).uniq
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
  if GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
    require_relative "lib/discourse_svdex/prototypes/company_profiles"
    Discourse::Application.routes.append do
      get "/company/:slug", to: "discourse_svdex/prototypes/company_profiles#page", constraints: { format: "html" }
      get "/company-profiles/:slug", to: "discourse_svdex/prototypes/company_profiles#show", defaults: { format: :json }
      put "/company-profiles/:slug", to: "discourse_svdex/prototypes/company_profiles#update", defaults: { format: :json }
    end
  end
  require_relative "lib/discourse_svdex/retired_information_pages"
  AboutController.prepend(DiscourseSvdex::RetiredAboutPage)
  StaticController.prepend(DiscourseSvdex::RetiredGuidelinesPages)
  require_relative "lib/discourse_svdex/company_directory"
  require_relative "lib/discourse_svdex/people_directory"
  require_relative "app/models/discourse_svdex/discovery"
  require_relative "lib/discourse_svdex/discoveries"
  require_relative "app/controllers/discourse_svdex/discoveries_controller"
  on(:user_added_to_group) { |user, _group, *_args| DiscourseSvdex::Discoveries.capture!(user) }
  on(:user_removed_from_group) { |user, _group, *_args| DiscourseSvdex::Discoveries.capture!(user) }
  on(:merging_users) { |source, target| DiscourseSvdex::Discoveries.merge!(source, target) }
  add_to_serializer(:admin_detailed_user, :svdex_discovery_entity) { DiscourseSvdex::Discoveries.kind(object) }
  add_to_serializer(:user, :svdex_discovery_entity, include_condition: -> { scope.is_staff? }) { DiscourseSvdex::Discoveries.kind(object) }
  add_to_serializer(:user, :svdex_discovery, include_condition: -> { DiscourseSvdex::Discoveries.visible?(object, scope) }) do
    DiscourseSvdex::Discoveries.credit(object, scope)
  end
  add_to_serializer(:user, :svdex_discoveries, include_condition: -> { DiscourseSvdex::Discoveries.visible?(object, scope) }) do
    DiscourseSvdex::Discoveries.history(object, scope, limit: 5)
  end
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
  require_relative "app/controllers/discourse_svdex/people_directory_controller"
  require_relative "app/controllers/discourse_svdex/private_access_controller"
  User.class_eval { attr_accessor :svdex_company_directory_details, :svdex_person_directory_details }
  add_to_serializer(:user_name, :svdex_person, include_condition: -> {
    object.is_a?(User) && object.svdex_person_directory_details && scope.public_can_see_profiles? && scope.can_see_profile?(object)
  }) { object.svdex_person_directory_details }
  add_to_serializer(:user, :svdex_affiliations, include_condition: -> { DiscourseSvdex::PeopleDirectory.profile_eligible?(object, scope) }) do
    DiscourseSvdex::PeopleDirectory.populate([object], scope)
    object.svdex_person_directory_details[:organizations]
  end
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
  require_relative "lib/discourse_svdex/topic_discovery"
  DiscourseSvdex::TopicDiscovery.install!(self)
  require_relative "lib/discourse_svdex/presales"
  DiscourseSvdex::Presales.install!(self)
  require_relative "lib/discourse_svdex/products"
  DiscourseSvdex::Products.install!(self)

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
    get "/people/directory_items", to: "discourse_svdex/people_directory#index", defaults: { format: :json }
    get "/people", to: "users#index", constraints: { format: "html" }
    get "/companies", to: "users#index", constraints: { format: "html" }
    get "/all-forums", to: "categories#index", constraints: { format: "html" }
    get "/discussion-forums", to: "categories#index", constraints: { format: "html" }
  end
end
