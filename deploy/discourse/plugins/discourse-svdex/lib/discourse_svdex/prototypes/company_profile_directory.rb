# frozen_string_literal: true
module DiscourseSvdex
  module Prototypes
    # Deliberately bounded to the local experiment. Reuses public fact payloads,
    # ranges and controls; production-scale SQL/index design remains separate.
    class CompanyProfileDirectory
      MONEY = { "svdex_funding" => "total_funding_usd", "svdex_valuation" => "last_valuation_usd", "svdex_aum" => "aum_usd", "svdex_buy_interest" => "buy", "svdex_sell_interest" => "sell" }.freeze
      def initialize(guardian, params)
        @guardian, @params = guardian, params
      end
      def payload
        page = @params[:page].to_s.presence || "0"
        raise Discourse::InvalidParameters.new(:page) unless page.match?(/\A\d{1,4}\z/)
        kind = @params[:kind].presence || "companies"
        raise Discourse::InvalidParameters.new(:kind) unless %w[companies funds people].include?(kind)
        scope = CompanyProfileRecord.where(kind: kind).order(:id)
        scope = scope.where(listed: true) unless @guardian.is_staff?
        all = scope.limit(501).to_a
        raise Discourse::InvalidParameters.new(:directory_size) if all.length > 500
        name = @params[:name].to_s.strip
        records = all.select { |record| record.name.downcase.include?(name.downcase) }
        return people_payload(records, all, page.to_i) if kind == "people"
        entries = records.map { |record| CompanyProfiles.payload(record, @guardian).slice(:profile, :company) }
        MONEY.each do |key, field|
          range = @params[key].presence
          next unless range
          if %w[buy sell].include?(field) && !InterestIndication.totals_visible?(@guardian)
            raise Discourse::InvalidAccess
          end
          raise Discourse::InvalidParameters.new(key) unless range == "undisclosed" || CompanyDirectory::RANGES.key?(range)
          entries.select! do |entry|
            value = %w[buy sell].include?(field) ? entry[:company].dig(:interest_totals, field) : entry[:company][field.to_sym]
            if range == "undisclosed"
              value.nil?
            else
              min, max = CompanyDirectory::RANGES.fetch(range)
              multiplier = %w[buy sell].include?(field) ? 100 : 1
              !value.nil? && (!min || value >= min * multiplier) && (!max || value < max * multiplier)
            end
          end
        end
        %w[svdex_sector svdex_stage svdex_location svdex_open svdex_type].each do |key|
          value = @params[key].presence
          next unless value
          if key == "svdex_open" && !%w[yes no].include?(value)
            raise Discourse::InvalidParameters.new(key)
          end
          entries.select! do |entry|
            company = entry[:company]
            actual = case key
            when "svdex_sector" then company.dig(:sector, :id)&.to_s
            when "svdex_stage" then company[:stage].presence || "undisclosed"
            when "svdex_location" then company[:headquarters_country].presence || "undisclosed"
            when "svdex_type" then company[:entity_type]
            when "svdex_open" then company[:open_offerings] > 0 ? "yes" : "no"
            end
            actual == value
          end
        end
        order = @params[:order].presence || (kind == "funds" ? "svdex_aum" : "svdex_total_funding")
        raise Discourse::InvalidParameters.new(:order) unless %w[username svdex_total_funding svdex_last_valuation svdex_aum svdex_buy_interest svdex_sell_interest].include?(order)
        if %w[svdex_buy_interest svdex_sell_interest].include?(order) && !InterestIndication.totals_visible?(@guardian)
          raise Discourse::InvalidAccess
        end
        ascending = @params[:asc].to_s == "true"
        entries.sort! do |a, b|
          av, bv = sort_value(a, order), sort_value(b, order)
          comparison = av.nil? ? (bv.nil? ? 0 : 1) : bv.nil? ? -1 : (ascending ? av <=> bv : bv <=> av)
          comparison.zero? ? a[:profile]["id"] <=> b[:profile]["id"] : comparison
        end
        { profiles: entries.slice(page.to_i * 25, 25).to_a, total: entries.length, has_more: entries.length > (page.to_i + 1) * 25,
          sectors: CompanyDirectory.tag_options("Sectors", @guardian), stages: all.filter_map { |record| record.facts["stage"].presence }.uniq.sort,
          locations: all.filter_map { |record| record.facts["headquarters_country"].presence }.uniq.sort }
      end
      def people_payload(records, all, page)
        PeopleDirectory.validate_filters!(@params.slice(*PeopleDirectory::FILTER_KEYS))
        entries = records.map { |record| CompanyProfiles.person_payload(record, @guardian).slice(:profile, :person) }
        if @params[:svdex_organization].present?
          entries.select! { |entry| entry[:person][:organizations].any? { |org| org[:id].to_s == @params[:svdex_organization].to_s } }
        end
        entries.select! { |entry| entry[:person][:location] == @params[:svdex_location] } if @params[:svdex_location].present?
        order = @params[:order].presence || "username"
        field = PeopleDirectory::SORT_FIELDS[order]
        raise Discourse::InvalidParameters.new(:order) unless order == "username" || field
        if field
          direction = @params[:asc].to_s == "true" ? 1 : -1
          entries.sort_by! do |entry|
            score = entry.dig(:person, field, :sort_value)
            [score.nil? ? 1 : 0, direction * score.to_i, entry[:profile]["name"].downcase, entry[:profile]["id"]]
          end
        else
          entries.sort_by! { |entry| [entry[:profile]["name"].downcase, entry[:profile]["id"]] }
          entries.reverse! unless @params[:asc].to_s == "true"
        end
        organizations = all.flat_map { |record| CompanyProfiles.person_payload(record, @guardian)[:person][:organizations] }.uniq { |org| org[:id] }.sort_by { |org| org[:name].downcase }
        { profiles: entries.slice(page * 25, 25).to_a, total: entries.length, has_more: entries.length > (page + 1) * 25,
          organizations: organizations.map { |org| org.slice(:id, :name) }, locations: all.filter_map { |record| record.facts["location"].presence }.uniq.sort }
      end
      def sort_value(entry, order)
        return entry[:profile]["name"].downcase if order == "username"
        return entry[:company].dig(:interest_totals, order.delete_prefix("svdex_").delete_suffix("_interest")) if order.end_with?("_interest")
        entry[:company][order.delete_prefix("svdex_").concat("_usd").to_sym]
      end
    end
  end
end
