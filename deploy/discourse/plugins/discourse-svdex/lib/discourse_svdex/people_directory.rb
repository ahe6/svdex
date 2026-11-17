# frozen_string_literal: true
module DiscourseSvdex
  # Public professional facts use native staff-maintained UserFields. Associations
  # come from explicit organization Key people links, never matching names.
  module PeopleDirectory
    FIELD_TYPE = "svdex_people"
    FIELDS = {
      "background" => ["Background", "Short factual background with named organizations or institutions: previous experience, education or current studies. Leave blank when unknown; do not force a former role."],
      "role" => ["Role", "Main professional role or title."],
      "focus" => ["Focus", "Sectors or areas of professional focus."],
      "net_worth" => ["Est. net worth", "Sourced estimate or range, including currency; never infer from company valuation alone."],
      "net_worth_source" => ["Net worth source", "Public https:// source supporting the estimate."],
      "net_worth_date" => ["Net worth as of", "Estimate date in YYYY-MM-DD format."],
      "net_worth_basis" => ["Net worth basis", "Basis, assumptions and limitations of the personal net worth estimate."],
    }.freeze

    def self.configure_fields!
      FIELDS.each_with_index do |(key, (label, description)), index|
        field = UserField.find_or_initialize_by(external_type: FIELD_TYPE, external_name: key)
        field.assign_attributes(name: label, description: description, field_type: "text", requirement: "optional",
          editable: false, show_on_signup: false, show_on_profile: true, show_on_user_card: false,
          searchable: false, position: 100 + index)
        field.save!
      end
    end

    def self.estimate(values)
      return nil unless %w[net_worth net_worth_source net_worth_date net_worth_basis].all? { |key| values[key].present? }
      url = URI.parse(values["net_worth_source"])
      return nil unless url.is_a?(URI::HTTPS) && url.host.present? && url.userinfo.nil?
      date = Date.iso8601(values["net_worth_date"])
      return nil unless date.iso8601 == values["net_worth_date"] && date <= Date.current
      { value: values["net_worth"], source: url.to_s, date: date.iso8601, basis: values["net_worth_basis"] }
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

    def self.visible_organizations(guardian)
      group = Group.find_by(name: SiteSetting.svdex_companies_group_name)
      return [] unless group && guardian.public_can_see_profiles? && guardian.can_see_group_and_members?(group)
      users = group.users.where(active: true, staged: false, admin: false, moderator: false)
      funds = Group.find_by(name: SiteSetting.svdex_funds_group_name)
      if funds && !guardian.can_see_group_and_members?(funds)
        users = users.where.not(id: GroupUser.where(group_id: funds.id).select(:user_id))
      end
      users.includes(:user_option, :user_stat, :user_custom_fields).select { |organization| guardian.can_see_profile?(organization) }
    end

    def self.person_ids(organization)
      Array(organization.custom_fields[CompanyDirectory::FIELDS.fetch("key_people")]).filter_map do |entry|
        entry["user_id"].to_i if entry.is_a?(Hash) && entry["user_id"].to_i > 0
      end.uniq
    end

    def self.filter_items(items, filters, guardian)
      if filters["svdex_organization"]
        organization = visible_organizations(guardian).find { |candidate| candidate.id == filters["svdex_organization"].to_i }
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
      organizations = visible_organizations(guardian).filter_map do |organization|
        next unless person_ids(organization).any? { |id| ids.include?(id) }
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
      ActiveRecord::Associations::Preloader.new(records: users, associations: [:user_custom_fields, :user_profile, :user_option, :user_stat]).call
      fields = UserField.public_fields.where(external_type: FIELD_TYPE).pluck(:external_name, :id).to_h
      person_ids = users.map(&:id).to_set
      references = Hash.new { |hash, key| hash[key] = [] }
      visible_organizations(guardian).each do |organization|
        Array(organization.custom_fields[CompanyDirectory::FIELDS.fetch("key_people")]).each do |entry|
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
        values = fields.transform_values { |id| user.user_fields[id.to_s].to_s.strip.presence }
        organizations = references[user.id].uniq { |entry| entry[:id] }
        user.svdex_person_directory_details = {
          background: ActionView::Base.full_sanitizer.sanitize(values["background"].to_s).strip.presence,
          organizations: organizations,
          role: values["role"] || organizations.filter_map { |entry| entry[:role] }.uniq.join(", ").presence,
          focus: values["focus"], location: user.user_profile.location.presence,
          net_worth: estimate(values),
        }
      end
    end
  end
end
