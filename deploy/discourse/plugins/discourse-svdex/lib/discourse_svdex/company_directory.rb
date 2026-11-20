# frozen_string_literal: true
module DiscourseSvdex
  module CompanyDirectory
    require_relative "organization_metadata"
    FIELDS = {
      **METADATA_TYPES.keys.to_h { |key| [key, "svdex_company_#{key}"] },
      "total_funding_usd" => "svdex_company_total_funding_usd",
      "last_valuation_usd" => "svdex_company_last_valuation_usd",
      "stage" => "svdex_company_stage",
      "headquarters_country" => "svdex_company_headquarters_country",
      "sector_tag_id" => "svdex_company_sector_tag_id",
      "company_tag_id" => "svdex_company_tag_id",
    }.freeze
    STAGES = ["Non-venture", "Pre-seed", "Seed", "Series A", "Series B", "Series C", "Series D+", "Growth", "Public"].freeze
    SORT_FIELDS = {
      "svdex_total_funding" => FIELDS.fetch("total_funding_usd"),
      "svdex_last_valuation" => FIELDS.fetch("last_valuation_usd"),
      "svdex_fund_size" => FIELDS.fetch("fund_size_usd"),
      "svdex_aum" => FIELDS.fetch("aum_usd"),
    }.freeze

    def self.company?(user)
      !user.staff? && user.groups.where(name: SiteSetting.svdex_companies_group_name).exists?
    end

    # Staff-managed public organization accounts are public profiles even while
    # new. Preserve global profile restrictions and explicit account privacy.
    def self.public_profile?(user, guardian)
      return false unless user&.active? && !user.staged? && guardian.public_can_see_profiles?
      return false if SiteSetting.allow_users_to_hide_profile && user.user_option&.hide_profile?
      group = Group.find_by(name: SiteSetting.svdex_companies_group_name)
      group && guardian.can_see_group_and_members?(group) && group.users.exists?(id: user.id)
    end

    module ProfileVisibility
      def can_see_profile?(user)
        super || CompanyDirectory.public_profile?(user, self)
      end
    end

    # Offering interest belongs to the tagged organization, never implicitly to
    # the topic author. Ambiguous or hidden profiles do not get a CTA.
    def self.interest_organization(topic, guardian)
      return nil unless guardian.can_see?(topic)
      users = User.joins(:groups).where(groups: { name: SiteSetting.svdex_companies_group_name })
        .where(id: UserCustomField.where(name: FIELDS.fetch("company_tag_id"), value: topic.tags.pluck(:id).map(&:to_s)).select(:user_id))
        .where(admin: false, moderator: false, active: true).distinct.includes(:user_option)
      visible = users.select { |user| guardian.can_see_profile?(user) }
      return nil unless visible.length == 1
      user = visible.first
      { id: user.id, name: user.name.presence || user.username, kind: user.groups.where(name: SiteSetting.svdex_funds_group_name).exists? ? "funds" : "companies" }
    end

    def self.tag_options(group_name, guardian)
      group = TagGroup.find_by_name_insensitive(group_name)
      return [] unless group
      DiscourseTagging.visible_tags(guardian).where(id: group.tags.select(:id)).order(:name).map do |tag|
        { id: tag.id, name: tag.name, slug: tag.slug, url: tag.url }
      end
    end

    def self.validate!(key, value)
      return validate_metadata!(key, value) if METADATA_TYPES.key?(key)
      return nil if value.nil? || value == ""
      if %w[total_funding_usd last_valuation_usd sector_tag_id company_tag_id].include?(key)
        min = key == "total_funding_usd" ? 0 : 1
        unless (value.is_a?(Integer) || value.is_a?(String) && value.match?(/\A\d{1,16}\z/)) && value.to_i.between?(min, DiscourseSvdex::MAX_VALUATION)
          raise Discourse::InvalidParameters.new(key)
        end
        value.to_i
      elsif key == "headquarters_country"
        raise Discourse::InvalidParameters.new(key) unless value.is_a?(String) && value.length <= 80 && !value.match?(/[[:cntrl:]<>\p{N}]/)
        value.strip.presence
      elsif key == "stage"
        raise Discourse::InvalidParameters.new(key) unless STAGES.include?(value)
        value
      else
        raise Discourse::InvalidParameters.new(key)
      end
    end

    FILTER_KEYS = %w[svdex_sector svdex_funding svdex_valuation svdex_stage svdex_location svdex_open svdex_type svdex_fund_size svdex_aum svdex_buy_interest svdex_sell_interest].freeze

    RANGES = { "under_1m" => [nil, 1_000_000], "1m_10m" => [1_000_000, 10_000_000], "10m_100m" => [10_000_000, 100_000_000], "100m_1b" => [100_000_000, 1_000_000_000], "over_1b" => [1_000_000_000, nil], "undisclosed" => nil }.freeze

    def self.validate_filters!(params)
      filters = params.stringify_keys.reject { |_key, value| value.blank? }
      %w[svdex_funding svdex_valuation svdex_fund_size svdex_aum svdex_buy_interest svdex_sell_interest].each do |key|
        raise Discourse::InvalidParameters.new(key) if filters[key] && !RANGES.key?(filters[key])
      end
      if filters["svdex_sector"]
        value = filters["svdex_sector"]
        group = TagGroup.find_by_name_insensitive("Sectors")
        raise Discourse::InvalidParameters.new(:svdex_sector) unless value.to_s.match?(/\A[0-9]+\z/) && group&.tags&.exists?(id: value.to_i)
        filters["svdex_sector"] = value.to_i
      end
      if filters["svdex_stage"] && !(STAGES + ["undisclosed"]).include?(filters["svdex_stage"])
        raise Discourse::InvalidParameters.new(:svdex_stage)
      end
      if filters["svdex_location"] && filters["svdex_location"] != "undisclosed"
        filters["svdex_location"] = validate!("headquarters_country", filters["svdex_location"])
      end
      if filters["svdex_open"] && !%w[yes no undisclosed].include?(filters["svdex_open"])
        raise Discourse::InvalidParameters.new(:svdex_open)
      end
      if filters["svdex_type"] && !%w[company spv].include?(filters["svdex_type"])
        raise Discourse::InvalidParameters.new(:svdex_type)
      end
      filters
    end

    def self.location_options(guardian)
      field = FIELDS.fetch("headquarters_country")
      users = User.joins(:groups).where(groups: { name: SiteSetting.svdex_companies_group_name })
        .where(id: UserCustomField.where(name: field).where.not(value: [nil, ""]).select(:user_id))
        .includes(:user_option, :user_stat)
      visible = users.select { |user| guardian.can_see_profile?(user) }
      User.custom_fields_for_ids(visible.map(&:id), [field]).values.filter_map { |fields| fields[field].presence }.uniq.sort_by(&:downcase)
    end

    def self.filter_items(items, filters, guardian)
      %w[buy sell].each do |side|
        range = filters["svdex_#{side}_interest"]
        items = InterestIndication.filter_items(items, side, range, guardian) if range
      end
      if filters["kind"] && filters["kind"] != "all"
        funds = GroupUser.where(group_id: Group.where(name: SiteSetting.svdex_funds_group_name).select(:id)).select(:user_id)
        items = filters["kind"] == "funds" ? items.where(user_id: funds) : items.where.not(user_id: funds)
      end
      if filters["svdex_type"]
        spvs = UserCustomField.where(name: FIELDS.fetch("entity_type"), value: "spv").select(:user_id)
        items = filters["svdex_type"] == "spv" ? items.where(user_id: spvs) : items.where.not(user_id: spvs)
      end
      if filters["svdex_sector"]
        items = items.where(user_id: UserCustomField.where(name: FIELDS.fetch("sector_tag_id"), value: filters["svdex_sector"].to_s).select(:user_id))
      end
      { "svdex_stage" => "stage", "svdex_location" => "headquarters_country" }.each do |filter, key|
        next unless filters[filter]
        present = UserCustomField.where(name: FIELDS.fetch(key)).where.not(value: [nil, ""])
        items = if filters[filter] == "undisclosed"
          items.where.not(user_id: present.select(:user_id))
        else
          items.where(user_id: present.where(value: filters[filter]).select(:user_id))
        end
      end
      if filters["svdex_open"]
        visible_tag_ids = tag_options("Companies", guardian).map { |tag| tag[:id].to_s }
        known = UserCustomField.where(name: FIELDS.fetch("company_tag_id"), value: visible_tag_ids)
        open_tag_ids = offering_scope(guardian).where(closed: false, archived: false).joins(:topic_tags).distinct.pluck("topic_tags.tag_id").map(&:to_s)
        items = case filters["svdex_open"]
        when "yes" then items.where(user_id: known.where(value: open_tag_ids).select(:user_id))
        when "no" then items.where.not(user_id: known.where(value: open_tag_ids).select(:user_id))
        else items.where.not(user_id: known.select(:user_id))
        end
      end
      { "svdex_funding" => "total_funding_usd", "svdex_valuation" => "last_valuation_usd", "svdex_fund_size" => "fund_size_usd", "svdex_aum" => "aum_usd" }.each do |filter, key|
        next unless filters[filter]
        field = FIELDS.fetch(key)
        present = UserCustomField.where(name: field).where("value ~ '^[0-9]{1,16}$'")
        if filters[filter] == "undisclosed"
          items = items.where.not(user_id: present.select(:user_id))
        else
          min, max = RANGES.fetch(filters[filter])
          amount = "CASE WHEN value ~ '^[0-9]{1,16}$' THEN value::bigint END"
          present = present.where("#{amount} >= ?", min) if min
          present = present.where("#{amount} < ?", max) if max
          items = items.where(user_id: present.select(:user_id))
        end
      end
      items
    end

    def self.offering_scope(guardian)
      category = Category.find_by(id: SiteSetting.svdex_listings_category_id)
      return Topic.none unless category && guardian.can_see?(category)
      Topic.visible.secured(guardian).listable_topics.where(category_id: DiscourseSvdex.offering_category_ids, archetype: Archetype.default).where.not(id: Category.where(id: DiscourseSvdex.offering_category_ids).where.not(topic_id: nil).select(:topic_id))
    end

    # Called once for the native directory page, not once per company. Counts
    # respect the current visitor's topic and tag permissions.
    def self.populate(users, guardian)
      return if users.empty?
      ActiveRecord::Associations::Preloader.new(records: users, associations: [:user_option, :user_stat]).call
      # Native custom_fields ignores the user_custom_fields AR association.
      # Use its typed bulk reader without changing the User instances' editable
      # field caches or introducing a second financial parsing implementation.
      fields_by_id = User.custom_fields_for_ids(users.map(&:id), FIELDS.values)
      fund_ids = GroupUser.where(user_id: users.map(&:id), group_id: Group.where(name: SiteSetting.svdex_funds_group_name).select(:id)).pluck(:user_id).to_set
      sectors = tag_options("Sectors", guardian).index_by { |tag| tag[:id] }
      companies = tag_options("Companies", guardian).index_by { |tag| tag[:id] }
      tag_ids = users.filter_map { |user| companies[fields_by_id.dig(user.id, FIELDS.fetch("company_tag_id")).to_i]&.fetch(:id) }.uniq
      linked = offering_scope(guardian).joins(:topic_tags).where(topic_tags: { tag_id: tag_ids })
      counts = linked.group("topic_tags.tag_id").distinct.count("topics.id")
      open_counts = linked.where(closed: false, archived: false).group("topic_tags.tag_id").distinct.count("topics.id")
      reference_ids = users.flat_map do |user|
        %w[key_people related_entities].flat_map { |key| Array(fields_by_id.dig(user.id, FIELDS.fetch(key))).filter_map { |entry| entry["user_id"] if entry.is_a?(Hash) } }
      end
      reference_users = User.where(id: reference_ids).includes(:user_option, :user_stat).index_by(&:id)
      interests = InterestIndication.totals(users.map(&:id), guardian)
      offerings_url = Category.find(SiteSetting.svdex_listings_category_id).url if tag_ids.any?
      users.each do |user|
        custom_fields = fields_by_id.fetch(user.id, {})
        values = FIELDS.transform_values { |field| custom_fields[field] }
        company_tag = companies[values["company_tag_id"].to_i]
        user.svdex_company_directory_details = {
          **metadata(user, guardian, reference_users, custom_fields: custom_fields, fund_ids: fund_ids),
          **(InterestIndication.totals_visible?(guardian) ? { interest_totals: interests[user.id] || {} } : {}),
          total_funding_usd: values["total_funding_usd"]&.to_i,
          last_valuation_usd: values["last_valuation_usd"]&.to_i,
          stage: values["stage"].presence,
          headquarters_country: values["headquarters_country"].presence,
          sector: sectors[values["sector_tag_id"].to_i],
          offerings: company_tag ? counts.fetch(company_tag[:id], 0) : nil,
          open_offering: company_tag ? open_counts.fetch(company_tag[:id], 0) > 0 : nil,
          open_offerings: company_tag ? open_counts.fetch(company_tag[:id], 0) : 0,
          company_tag: company_tag,
          open_offerings_url: company_tag ? "/tags#{offerings_url}/#{company_tag[:slug]}/#{company_tag[:id]}?svdex_active=1" : nil,
          offerings_url: company_tag ? "/tags#{offerings_url}/#{company_tag[:slug]}/#{company_tag[:id]}" : nil,
        }
      end
    end

    # Count only explicit Key people links on organization profiles the viewer
    # can see. Do not infer ownership from names, email or private applications.
    def self.member_organization_counts(guardian)
      group = Group.find_by(name: SiteSetting.svdex_companies_group_name)
      return {} unless group && guardian.public_can_see_profiles? && guardian.can_see_group_and_members?(group)
      counts = Hash.new(0)
      organizations = group.users.where(active: true, staged: false, admin: false, moderator: false)
        .includes(:user_option, :user_stat)
      organizations = organizations.select { |organization| guardian.can_see_profile?(organization) }
      key_people = FIELDS.fetch("key_people")
      fields_by_id = User.custom_fields_for_ids(organizations.map(&:id), [key_people])
      organizations.each do |organization|
        ids = Array(fields_by_id.dig(organization.id, key_people)).filter_map do |entry|
          entry["user_id"].to_i if entry.is_a?(Hash) && entry["user_id"].to_i > 0
        end
        ids.uniq.each { |id| counts[id] += 1 }
      end
      # Match the public Key people renderer: a private person's association
      # must not become discoverable through a count on the Users page.
      people = User.where(id: counts.keys).includes(:user_option, :user_stat)
      counts.slice(*people.select { |person| guardian.can_see_profile?(person) }.map(&:id))
    end

    module Query
      def call(**options)
        @svdex_people_filters = options.delete(:svdex_people_filters) || {}
        catalog = options.delete(:svdex_catalog)
        @svdex_people_directory = catalog == "people" && options[:group_name] == SiteSetting.svdex_people_group_name
        @svdex_filters = options.delete(:svdex_filters) || {}
        @svdex_company_directory = catalog == "companies" && options[:group_name] == SiteSetting.svdex_companies_group_name
        # Business facts are current company facts, not weekly activity totals.
        options[:period_type] = DirectoryItem.period_types[:all] if @svdex_company_directory
        result = super(**options)
        if @svdex_company_directory
          CompanyDirectory.populate(result.items.map(&:user), guardian)
        elsif @svdex_people_directory
          PeopleDirectory.populate(result.items.map(&:user), guardian)
        else
          counts = @svdex_member_organizations ||= CompanyDirectory.member_organization_counts(guardian)
          result.items.each { |item| item.svdex_organizations = counts.fetch(item.user_id, 0) }
        end
        result
      ensure
        @svdex_people_directory = false
        @svdex_people_filters = {}
        @svdex_company_directory = false
        @svdex_filters = {}
        @svdex_visible_company_user_ids = nil
        @svdex_member_organizations = nil
      end

      private

      # Curated classification is independent of who owns or operates an account.
      # Filter before native totals/pagination; native group visibility still applies.
      def filter_group(items, group_name)
        items = super
        return items unless @svdex_people_directory

        organization_ids = GroupUser.joins(:user).where(users: { admin: false, moderator: false }).where(group_id: Group.where(name: [
          SiteSetting.svdex_companies_group_name,
          SiteSetting.svdex_funds_group_name,
        ]).select(:id)).select(:user_id)
        items.joins(:user).where.not(user_id: organization_ids)
          .where("NULLIF(BTRIM(users.name), '') IS NOT NULL")
      end

      # Classification is independent of identity, activity and login history.
      # Include managed profiles only in the explicitly scoped catalogs. Apply
      # before totals/pagination and prevent native current-user reinsertion.
      def exclude_groups(items, group_names)
        items, excluded_ids = super
        return items, excluded_ids if @svdex_company_directory || @svdex_people_directory

        maintained = GroupUser.where(group_id: Group.where(name: SiteSetting.svdex_maintained_accounts_group_name).select(:id))
        excluded_ids |= [user.id] if user && maintained.exists?(user_id: user.id)
        [items.where.not(user_id: maintained.select(:user_id)), excluded_ids]
      end

      def visible_company_user_ids(items)
        @svdex_visible_company_user_ids ||= User.where(id: items.select(:user_id), admin: false, moderator: false)
          .includes(:user_option, :user_stat).select { |account| guardian.can_see_profile?(account) }.map(&:id)
      end

      def order_items(items, requested_order, ascending)
        if @svdex_people_directory
          # Native name/username search has already narrowed the relation here.
          # Visibility still applies before native counts, ordering and paging.
          items = PeopleDirectory.filter_items(items, @svdex_people_filters, guardian)
          visible_ids = User.where(id: items.select(:user_id)).includes(:user_option, :user_stat)
            .select { |person| guardian.can_see_profile?(person) }.map(&:id)
          items = items.where(user_id: visible_ids)
          field = PeopleDirectory::SORT_FIELDS[requested_order]
          return PeopleDirectory.sort_items(items, visible_ids, field, ascending) if field
        end
        if @svdex_people_directory && requested_order == "username"
          return items.joins(:user).order(Arel.sql("LOWER(BTRIM(users.name)) #{ascending ? 'ASC' : 'DESC'}"), id: :asc)
        end
        if !@svdex_company_directory && requested_order == "svdex_organizations"
          counts = @svdex_member_organizations ||= CompanyDirectory.member_organization_counts(guardian)
          cases = counts.map { |id, count| "WHEN #{Integer(id)} THEN #{Integer(count)}" }.join(" ")
          expression = cases.empty? ? "0::integer" : "CASE directory_items.user_id #{cases} ELSE 0 END"
          return items.order(Arel.sql("(#{expression}) #{ascending ? 'ASC' : 'DESC'}"), id: :asc)
        end
        if @svdex_company_directory
          # A hidden financial disclosure must not be inferred through a filter.
          if CompanyDirectory::FILTER_KEYS.any? { |key| @svdex_filters[key].present? }
            items = items.where(user_id: visible_company_user_ids(items))
          end
          items = items.joins(:user).where(users: { admin: false, moderator: false })
          items = CompanyDirectory.filter_items(items, @svdex_filters, guardian)
        end
        if @svdex_company_directory && requested_order == "username"
          # Company pages display real company names, with username fallback.
          name = "LOWER(COALESCE(NULLIF(BTRIM(users.name), ''), users.username))"
          return items.joins(:user).order(Arel.sql("#{name} #{ascending ? 'ASC' : 'DESC'}"), :id => :asc)
        end
        if @svdex_company_directory && %w[svdex_buy_interest svdex_sell_interest].include?(requested_order)
          return InterestIndication.sort_items(items, requested_order == "svdex_buy_interest" ? "buy" : "sell", ascending, guardian)
        end
        field = CompanyDirectory::SORT_FIELDS[requested_order]
        return super unless @svdex_company_directory && field
        # Keep missing disclosures last in both directions. Never sort formatted
        # money strings, and keep legacy malformed values out of numeric casts.
        quoted = ActiveRecord::Base.connection.quote(field)
        visible_ids = visible_company_user_ids(items).presence || [0]
        amount = "CASE WHEN directory_items.user_id IN (#{visible_ids.join(',')}) AND company_amount.value ~ '^[0-9]{1,16}$' THEN company_amount.value::bigint END"
        items.joins("LEFT JOIN user_custom_fields company_amount ON company_amount.user_id = directory_items.user_id AND company_amount.name = #{quoted}")
          .order(Arel.sql("#{amount} #{ascending ? 'ASC' : 'DESC'} NULLS LAST"), :id => :asc)
      end
    end
  end
end
