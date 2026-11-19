# frozen_string_literal: true
require "uri"
module DiscourseSvdex
  module CompanyDirectory
    # These are staff-maintained disclosures, not editable user-profile fields.
    METADATA_TYPES = {
      "entity_type" => :string, "key_people" => :json, "related_entities" => :json,
      "strategy_focus" => :string, "manager_name" => :string, "manager_url" => :string,
      "aum_usd" => :integer, "fund_size_usd" => :integer, "fund_size_basis" => :string,
      "fund_life" => :string, "vintage_year" => :integer, "fund_domicile" => :string,
      "facts_as_of" => :string, "source_url" => :string,
    }.freeze

    def self.validate_metadata!(key, value)
      invalid = -> { raise Discourse::InvalidParameters.new(key) }
      return nil if value.nil? || value == ""
      case key
      when "entity_type"
        invalid.call unless %w[company spv].include?(value)
      when "fund_size_basis"
        invalid.call unless %w[commitments raised target].include?(value)
      when "aum_usd", "fund_size_usd", "vintage_year"
        invalid.call unless value.to_s.match?(/\A\d{1,16}\z/)
        value = value.to_i
        invalid.call unless key == "vintage_year" ? value.between?(1800, 2200) : value.between?(0, DiscourseSvdex::MAX_VALUATION)
      when "facts_as_of"
        invalid.call unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && (Date.iso8601(value) rescue nil)
      when "manager_url", "source_url"
        value = validate_public_url!(key, value)
      when "key_people", "related_entities"
        invalid.call unless value.is_a?(Array) && value.length <= 20
        allowed = %w[name role url user_id]
        value = value.map do |entry|
          invalid.call unless entry.is_a?(Hash) && (entry.keys.map(&:to_s) - allowed).empty?
          entry = entry.stringify_keys
          %w[name role].each do |field|
            invalid.call unless entry[field].is_a?(String) && entry[field].strip.present? && entry[field].length <= 120 && !entry[field].match?(/[[:cntrl:]<>]/)
            entry[field] = entry[field].strip
          end
          if key == "related_entities"
            invalid.call unless %w[Underlying Sponsor Manager].include?(entry["role"])
          end
          entry["url"] = validate_public_url!(key, entry["url"]) if entry["url"].present?
          if entry["user_id"].present?
            invalid.call unless entry["user_id"].to_s.match?(/\A[1-9]\d*\z/) && User.exists?(id: entry["user_id"].to_i)
            entry["user_id"] = entry["user_id"].to_i
          else
            entry.delete("user_id")
          end
          entry.compact
        end
      else
        invalid.call unless METADATA_TYPES[key] == :string && value.is_a?(String) && value.length <= 240 && !value.match?(/[[:cntrl:]<>]/)
        value = value.strip.presence
      end
      value
    end

    def self.validate_public_url!(key, value)
      uri = URI.parse(value.to_s)
      unless value.is_a?(String) && value.length <= 1000 && %w[http https].include?(uri.scheme) && uri.host.present? && !uri.userinfo && !value.match?(/[[:cntrl:]]/)
        raise Discourse::InvalidParameters.new(key)
      end
      value
    rescue URI::InvalidURIError
      raise Discourse::InvalidParameters.new(key)
    end

    def self.public_references(entries, guardian, reference_users = nil)
      Array(entries).filter_map do |entry|
        next unless entry.is_a?(Hash) && entry["name"].present?
        result = entry.slice("name", "role", "url")
        # Only an explicit staff association may link to a member, and its
        # privacy still applies. Names never trigger automatic user matching.
        if entry["user_id"]
          user = reference_users ? reference_users[entry["user_id"].to_i] : User.find_by(id: entry["user_id"])
          result["url"] = user.relative_url if user && guardian.can_see_profile?(user)
        end
        result
      end
    end

    def self.metadata(user, guardian, reference_users = nil, custom_fields: user.custom_fields, fund_ids: nil)
      values = METADATA_TYPES.keys.to_h { |key| [key.to_sym, custom_fields[FIELDS.fetch(key)]] }
      values[:key_people] = public_references(values[:key_people], guardian, reference_users)
      values[:related_entities] = public_references(values[:related_entities], guardian, reference_users)
      is_fund = fund_ids ? fund_ids.include?(user.id) : user.groups.where(name: SiteSetting.svdex_funds_group_name).exists?
      values[:kind] = is_fund ? "funds" : "companies"
      values[:entity_type] ||= "company"
      values
    end
  end
end
