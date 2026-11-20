# frozen_string_literal: true
require "date"
require "uri"

module DiscourseSvdex
  # Public professional facts use native staff-maintained UserFields. Associations
  # come from explicit organization Key people links, never matching names.
  module PeopleDirectory
    FIELD_TYPE = "svdex_people"
    BIRTH_YEAR_FIELDS = %w[birth_year birth_year_source].freeze
    NET_WORTH_FIELDS = %w[net_worth net_worth_source net_worth_date net_worth_basis].freeze
    DIRECTORY_ONLY_FIELDS = (BIRTH_YEAR_FIELDS + NET_WORTH_FIELDS).freeze
    NET_WORTH_BANDS = {
      100_000 => "$100k+",
      1_000_000 => "$1M+",
      10_000_000 => "$10M+",
      100_000_000 => "$100M+",
    }.freeze
    NET_WORTH_UNITS = { "k" => 1_000, "m" => 1_000_000, "b" => 1_000_000_000, "t" => 1_000_000_000_000 }.freeze
    LEGACY_NET_WORTH_AMOUNT = /\A(?<currency>\$|USD\s+)?(?<number>\d{1,3}(?:,\d{3})+|\d+)(?:\.(?<fraction>\d+))?\s*(?<unit>[kmbt])?\z/i
    FIELDS = {
      "background" => ["Background", "Short factual background with named organizations or institutions: previous experience, education or current studies. Leave blank when unknown; do not force a former role."],
      "role" => ["Role", "Main professional role or title."],
      "focus" => ["Focus", "Sectors or areas of professional focus."],
      "net_worth" => ["All-Time Money", "Use a sourced USD amount or band, such as $1,250,000 or $1M+."],
      "net_worth_source" => ["Net worth source", "Public https:// source supporting the estimate."],
      "net_worth_date" => ["Net worth as of", "Estimate date in YYYY-MM-DD format."],
      "net_worth_basis" => ["Net worth basis", "Basis, assumptions and limitations of the personal net worth estimate."],
      "birth_year" => ["Birth year or range", "Publicly sourced year of birth or a range such as 1980–1984."],
      "birth_year_source" => ["Birth year source", "Public HTTPS source supporting the birth year."],
    }.freeze

    SORT_FIELDS = { "svdex_age" => :age, "svdex_net_worth" => :net_worth }.freeze

    def self.birth_years(value)
      match = /\A(\d{4})(?:\s*[-–—]\s*(\d{4}))?\z/.match(value.to_s)
      return unless match
      first = match[1].to_i
      last = match[2] ? match[2].to_i : first
      [first, last] if first >= 1800 && first <= last && last <= Date.today.year
    end

    def self.estimated_age(values)
      years = birth_years(values["birth_year"])
      source = values["birth_year_source"]
      current_year = Date.today.year
      return unless years && source.is_a?(String) && source.bytesize <= 1000

      url = URI.parse(source)
      return unless url.is_a?(URI::HTTPS) && url.host.to_s.include?(".") && !url.userinfo

      youngest, oldest = years.reverse.map { |year| current_year - year }
      value = youngest == oldest ? "~#{youngest}" : "~#{youngest}–#{oldest}"
      { value: value, source: source, sort_value: youngest }
    rescue URI::InvalidURIError
      nil
    end

    def self.configure_fields!
      FIELDS.each_with_index do |(key, (label, description)), index|
        field = UserField.find_or_initialize_by(external_type: FIELD_TYPE, external_name: key)
        field.assign_attributes(name: label, description: description, field_type: "text", requirement: "optional",
          editable: false, show_on_signup: false, show_on_profile: !DIRECTORY_ONLY_FIELDS.include?(key), show_on_user_card: false,
          searchable: false, position: 100 + index)
        field.save!
      end
    end

    def self.net_worth_lower_bound(value)
      return unless value.is_a?(String)
      text = value.strip
      # Older entries may contain a USD amount or a range. Read the lower end,
      # including shared suffixes such as the M in $10–20M.
      lower, upper = text.delete_suffix("+").split(/\s*[-–—]\s*/, 2).map { |part| LEGACY_NET_WORTH_AMOUNT.match(part) }
      return unless lower && (lower[:currency] || upper&.[](:currency))
      return if text.match?(/[-–—]/) && !upper

      unit = lower[:unit]
      unit ||= upper[:unit] if upper && !upper[:currency] && lower[:number].match?(/\A\d{1,3}\z/)
      amount = net_worth_amount(lower, unit)
      return if upper && net_worth_amount(upper, upper[:unit]) < amount

      amount
    end
    private_class_method :net_worth_lower_bound

    def self.net_worth_amount(parts, unit)
      amount = [parts[:number].delete(","), parts[:fraction]].compact.join(".")
      Rational(amount) * NET_WORTH_UNITS.fetch(unit&.downcase, 1)
    end
    private_class_method :net_worth_amount

    def self.net_worth_value(value)
      return unless value.is_a?(String)
      text = value.strip
      amount = net_worth_lower_bound(text)
      return unless amount
      if text.end_with?("+") || text.match?(/[-–—]/)
        band = NET_WORTH_BANDS.reverse_each.find { |minimum, _label| amount >= minimum }
        return unless band
        amount, text = band
      end
      { value: text, sort_value: (amount * 100).floor }
    end

    def self.valid_catalog_net_worth?(value)
      net_worth_value(value)&.fetch(:value) == value
    end

    def self.estimate(values)
      return nil unless NET_WORTH_FIELDS.all? { |key| values[key].present? }
      disclosure = net_worth_value(values["net_worth"])
      return nil unless disclosure
      url = URI.parse(values["net_worth_source"])
      return nil unless url.is_a?(URI::HTTPS) && url.host.present? && url.userinfo.nil?
      date = Date.iso8601(values["net_worth_date"])
      return nil unless date.iso8601 == values["net_worth_date"] && date <= Date.current
      disclosure.merge(source: url.to_s, date: date.iso8601)
    rescue URI::InvalidURIError, Date::Error
      nil
    end

    FILTER_KEYS = %w[svdex_organization svdex_location].freeze

    def self.validate_filters!(params)
      filters = params.stringify_keys.reject { |_key, value| value.blank? }
      if filters["svdex_organization"] && !filters["svdex_organization"].to_s.match?(/\A[1-9][0-9]{0,15}\z/)
        raise Discourse::InvalidParameters.new(:svdex_organization)
      end
      if filters["svdex_location"] && (!filters["svdex_location"].is_a?(String) || filters["svdex_location"].length > 120 || filters["svdex_location"].match?(/[[:cntrl:]]/))
        raise Discourse::InvalidParameters.new(:svdex_location)
      end
      filters
    end

    def self.visible_organizations(guardian, ids: nil)
      group = Group.find_by(name: SiteSetting.svdex_companies_group_name)
      return [] unless group && guardian.public_can_see_profiles? && guardian.can_see_group_and_members?(group)
      users = group.users.where(active: true, staged: false, admin: false, moderator: false)
      users = users.where(id: ids) if ids
      funds = Group.find_by(name: SiteSetting.svdex_funds_group_name)
      if funds && !guardian.can_see_group_and_members?(funds)
        users = users.where.not(id: GroupUser.where(group_id: funds.id).select(:user_id))
      end
      users.includes(:user_option, :user_stat).select { |organization| guardian.can_see_profile?(organization) }
    end

    def self.person_ids(organization, fields: organization.custom_fields)
      Array(fields[CompanyDirectory::FIELDS.fetch("key_people")]).filter_map do |entry|
        entry["user_id"].to_i if entry.is_a?(Hash) && entry["user_id"].to_i > 0
      end.uniq
    end

    def self.filter_items(items, filters, guardian)
      if filters["svdex_organization"]
        organization = visible_organizations(guardian, ids: [filters["svdex_organization"].to_i]).first
        items = items.where(user_id: organization ? person_ids(organization) : [])
      end
      if filters["svdex_location"]
        items = items.joins(user: :user_profile).where(user_profiles: { location: filters["svdex_location"] })
      end
      items
    end

    # Options come from the whole accessible catalog, not the current page or
    # filtered results, so applying one selection does not remove other choices.
    def self.filter_options(guardian)
      group = Group.find_by(name: SiteSetting.svdex_people_group_name)
      return { organizations: [], locations: [] } unless group && guardian.can_see_group_and_members?(group)
      organization_ids = GroupUser.where(group_id: Group.where(name: [SiteSetting.svdex_companies_group_name, SiteSetting.svdex_funds_group_name]).select(:id)).select(:user_id)
      candidates = group.users.where(id: DirectoryItem.where(period_type: DirectoryItem.period_types[:all]).select(:user_id))
        .where("NULLIF(BTRIM(users.name), '') IS NOT NULL").where.not(id: User.where(id: organization_ids, admin: false, moderator: false).select(:id))
        .includes(:user_option, :user_stat, :user_profile)
      people = candidates.select { |person| guardian.can_see_profile?(person) }
      ids = people.map(&:id).to_set
      visible = visible_organizations(guardian)
      fields_by_id = User.custom_fields_for_ids(visible.map(&:id), [CompanyDirectory::FIELDS.fetch("key_people")])
      organizations = visible.filter_map do |organization|
        next unless person_ids(organization, fields: fields_by_id.fetch(organization.id, {})).any? { |id| ids.include?(id) }
        { id: organization.id, name: organization.name.presence || organization.username }
      end.sort_by { |organization| organization[:name].downcase }
      { organizations: organizations, locations: people.filter_map { |person| person.user_profile.location.presence }.uniq.sort }
    end

    def self.background(user)
      field = UserField.public_fields.find_by(external_type: FIELD_TYPE, external_name: "background")
      field && ActionView::Base.full_sanitizer.sanitize(user.user_fields[field.id.to_s].to_s).strip.presence
    end

    def self.profile_eligible?(user, guardian)
      group = Group.find_by(name: SiteSetting.svdex_people_group_name)
      user && !user.staff? && !CompanyDirectory.company?(user) && user.active? && !user.staged? && user.name.present? &&
        guardian.public_can_see_profiles? && guardian.can_see_profile?(user) && group &&
        guardian.can_see_group_and_members?(group) && group.users.exists?(id: user.id)
    end

    def self.populate(users, guardian)
      return if users.empty?
      ActiveRecord::Associations::Preloader.new(records: users, associations: [:user_profile, :user_option, :user_stat]).call
      person_ids = users.map(&:id).to_set
      facts_by_id = facts_by_user(person_ids.to_a)
      references = Hash.new { |hash, key| hash[key] = [] }
      visible = visible_organizations(guardian)
      key_people = CompanyDirectory::FIELDS.fetch("key_people")
      fields_by_id = User.custom_fields_for_ids(visible.map(&:id), [key_people])
      visible.each do |organization|
        Array(fields_by_id.dig(organization.id, key_people)).each do |entry|
          next unless entry.is_a?(Hash) && person_ids.include?(entry["user_id"].to_i)
          references[entry["user_id"].to_i] << {
            id: organization.id, name: organization.name.presence || organization.username,
            username: organization.username, avatar_template: organization.avatar_template,
            url: "/u/#{organization.username}/summary", role: entry["role"].presence,
          }
        end
      end
      users.each do |user|
        next unless guardian.can_see_profile?(user)
        values = facts_by_id.fetch(user.id)
        organizations = references[user.id].uniq { |entry| entry[:id] }
        user.svdex_person_directory_details = {
          background: ActionView::Base.full_sanitizer.sanitize(values["background"].to_s).strip.presence,
          organizations: organizations,
          role: values["role"] || organizations.filter_map { |entry| entry[:role] }.uniq.join(", ").presence,
          focus: values["focus"], location: user.user_profile.location.presence,
          age: estimated_age(values),
          net_worth: estimate(values),
        }
      end
    end

    def self.facts_by_user(ids)
      people_fields = UserField.where(external_type: FIELD_TYPE)
      fields = people_fields.public_fields.or(people_fields.where(external_name: DIRECTORY_ONLY_FIELDS))
        .pluck(:external_name, :id).to_h.transform_values { |id| "#{User::USER_FIELD_PREFIX}#{id}" }
      facts = User.custom_fields_for_ids(ids, fields.values)
      ids.to_h { |id| [id, fields.transform_values { |field| facts.dig(id, field).to_s.strip.presence }] }
    end

    def self.sort_items(items, ids, field, ascending)
      cases = facts_by_user(ids).filter_map do |id, values|
        disclosure = field == :age ? estimated_age(values) : estimate(values)
        "WHEN #{Integer(id)} THEN #{Integer(disclosure[:sort_value])}" if disclosure
      end
      name = "LOWER(BTRIM(users.name))"
      sorted = items.joins(:user)
      if cases.any?
        sorted = sorted.order(Arel.sql("CASE directory_items.user_id #{cases.join(" ")} END #{ascending ? 'ASC' : 'DESC'} NULLS LAST"))
      end
      sorted.order(Arel.sql("#{name} ASC"), id: :asc)
    end
  end
end
