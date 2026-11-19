# frozen_string_literal: true
# Local feasibility spike. No production migration, route or account conversion.
module DiscourseSvdex
  module Prototypes
    class CompanyProfileRecord < ActiveRecord::Base
      self.table_name = "svdex_company_profile_records"
      belongs_to :official_account, class_name: "User", optional: true
      belongs_to :logo_upload, class_name: "Upload", optional: true
      has_many :upload_references, as: :target, dependent: :destroy
      after_save do
        UploadReference.ensure_exist!(upload_ids: [logo_upload_id], target: self) if saved_change_to_logo_upload_id?
      end
      validates :name, presence: true, length: { maximum: 120 }
      validates :summary, length: { maximum: 180 }
      validates :kind, inclusion: { in: %w[companies funds people] }
      def profile_url
        "/#{kind == 'funds' ? 'fund' : kind == 'people' ? 'person' : 'company'}/#{slug}"
      end
      def api_path
        "/#{kind == 'funds' ? 'fund' : kind == 'people' ? 'person' : 'company'}-profiles/#{slug}"
      end
      validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
    end

    module CompanyProfiles
      REFERENCE_FACTS = %w[key_people related_entities].freeze
      FACTS = %w[total_funding_usd last_valuation_usd sector_tag_id company_tag_id stage headquarters_country].freeze
      FUND_FACTS = %w[aum_usd strategy_focus vintage_year fund_life fund_domicile entity_type manager_name].freeze
      PERSON_FACTS = %w[role focus location net_worth net_worth_source net_worth_date net_worth_basis].freeze
      def self.ensure_local!
        raise Discourse::NotFound unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
      end
      def self.setup!
        ensure_local!
        connection = ActiveRecord::Base.connection
        unless connection.data_source_exists?(CompanyProfileRecord.table_name)
          connection.create_table(CompanyProfileRecord.table_name) do |t|
            t.string :slug, null: false
            t.string :name, null: false
            t.text :summary
            t.boolean :listed, default: false, null: false
            t.bigint :official_account_id
            t.jsonb :facts, default: {}, null: false
            t.timestamps null: false
          end
          connection.add_index(CompanyProfileRecord.table_name, :slug, unique: true)
          connection.add_foreign_key(CompanyProfileRecord.table_name, :users, column: :official_account_id, on_delete: :nullify)
        end
        unless connection.column_exists?(CompanyProfileRecord.table_name, :logo_upload_id)
          connection.add_column CompanyProfileRecord.table_name, :logo_upload_id, :bigint
          connection.add_foreign_key CompanyProfileRecord.table_name, :uploads, column: :logo_upload_id, on_delete: :nullify
        end
        unless connection.column_exists?(CompanyProfileRecord.table_name, :kind)
          connection.add_column CompanyProfileRecord.table_name, :kind, :string, null: false, default: "companies"
          connection.add_check_constraint CompanyProfileRecord.table_name, "kind IN ('companies','funds','people')", name: "svdex_profile_kind"
        end
        CompanyRelationships.setup!
        CompanyCatalog.setup!
        CompanyProfileRecord.reset_column_information
      end
    end

    class CompanyProfilesController < ::ApplicationController
      requires_plugin PLUGIN_NAME
      before_action do
        CompanyProfiles.ensure_local!
        response.headers["Cache-Control"] = "private, no-store" if guardian.is_staff?
        raise Discourse::NotFound unless ActiveRecord::Base.connection.data_source_exists?(CompanyProfileRecord.table_name)
      end
      before_action :ensure_staff, only: %i[update discovery update_discovery]
      skip_before_action :check_xhr, only: %i[page directory]
      def page
        profile!
        render "default/empty"
      end
      def show
        render_json_dump(payload(profile!))
      end
      def index
        render_json_dump(CompanyProfileDirectory.new(guardian, params.merge(kind: profile_kind)).payload)
      end
      def directory
        render "default/empty"
      end
      def discovery
        render_json_dump(CompanyRelationships.discovery_payload(profile!))
      end
      def update_discovery
        record = profile!
        CompanyRelationships.record_discovery!(record, current_user, params.require(:discovery).permit(:provenance, :status, :contributor, :listed_at, :reason).to_h)
        render_json_dump(CompanyRelationships.discovery_payload(record))
      end
      def suggest
        raise Discourse::InvalidAccess unless current_user
        response.headers["Cache-Control"] = "private, no-store"
        RateLimiter.new(current_user, "svdex-company-correction", 5, 1.hour).performed!
        record = profile!
        values = params.require(:suggestion).permit(:revision, :name, :summary, :total_funding_usd, :last_valuation_usd, :as_of, :source_url, :reason).to_h
        topic = CompanyCatalog.suggest!(record, current_user, values)
        render_json_dump(url: topic.relative_url)
      rescue CatalogDocument::Invalid => error
        raise Discourse::InvalidParameters.new(error.message)
      end
      def update
        record = profile!
        allowed = record.kind == "people" ? CompanyProfiles::PERSON_FACTS : CompanyProfiles::FACTS + CompanyProfiles::FUND_FACTS
        data = params.require(:profile).permit(:name, :summary, :official_username, facts: allowed).to_h
        record.with_lock do
          if CompanyCatalog.managed?(record) && (data.key?("name") || data.key?("summary") || data.fetch("facts", {}).keys.any? { |key| CompanyCatalog::FACTS.include?(key) })
            raise Discourse::InvalidParameters.new("Submit a correction for reviewed company facts")
          end
          record.name = data["name"] if data.key?("name")
          record.summary = data["summary"] if data.key?("summary")
          if data.key?("official_username")
            account = User.find_by_username(data["official_username"].to_s.strip) if data["official_username"].present?
            raise Discourse::InvalidParameters.new(:official_username) if data["official_username"].present? && (!account&.active? || account.staged?)
            record.official_account = account
          end
          facts = (data["facts"] || {}).to_h do |key, value|
            if record.kind == "people"
              raise Discourse::InvalidParameters.new(key) unless value.nil? || value.is_a?(String) && value.length <= 1000 && !value.match?(/[\u0000-\u0008]/)
              [key, value.to_s.strip.presence]
            else
              [key, CompanyDirectory.validate!(key, value)]
            end
          end
          if record.kind == "people" && facts.keys.any? { |key| key.start_with?("net_worth") }
            merged = record.facts.merge(facts)
            if merged.slice(*CompanyProfiles::PERSON_FACTS.grep(/^net_worth/)).values.any?(&:present?) && PeopleDirectory.estimate(merged).nil?
              raise Discourse::InvalidParameters.new("Net worth needs a public HTTPS source, date and basis")
            end
          end
          { "sector_tag_id" => "Sectors", "company_tag_id" => "Companies" }.each do |key, group|
            if facts[key] && CompanyDirectory.tag_options(group, guardian).none? { |tag| tag[:id] == facts[key] }
              raise Discourse::InvalidParameters.new(key)
            end
          end
          record.facts = record.facts.merge(facts)
          raise Discourse::InvalidParameters.new(:profile) unless record.save
          StaffActionLogger.new(current_user).log_custom("svdex_company_profile_details", profile_id: record.id, fields: data.keys.join(", "))
        end
        render_json_dump(payload(record))
      end
      def profile!
        record = CompanyProfileRecord.find_by!(slug: params[:slug], kind: profile_kind)
        raise Discourse::NotFound unless record.listed || guardian.is_staff?
        record
      end
      def payload(record)
        CompanyProfiles.payload(record, guardian)
      end
      def profile_kind
        kind = params[:kind].presence || "companies"
        raise Discourse::InvalidParameters.new(:kind) unless %w[companies funds people].include?(kind)
        kind
      end
    end
    module CompanyProfiles
      def self.payload(record, guardian)
        return person_payload(record, guardian) if record.kind == "people"
        account = record.official_account
        visible_account = account && account.active? && !account.staged? && guardian.public_can_see_profiles? && guardian.can_see_profile?(account)
        tag = CompanyDirectory.tag_options("Companies", guardian).find { |item| item[:id] == record.facts["company_tag_id"] }
        sector = CompanyDirectory.tag_options("Sectors", guardian).find { |item| item[:id] == record.facts["sector_tag_id"] }
        offerings = tag ? CompanyDirectory.offering_scope(guardian).joins(:tags).where(tags: { id: tag[:id] }).distinct : Topic.none
        updates_category = Category.find_by(id: SiteSetting.svdex_introductions_category_id)
        updates = tag && updates_category && guardian.can_see?(updates_category) ? Topic.visible.secured(guardian).listable_topics.where(category_id: updates_category.id, archetype: Archetype.default).where.not(id: updates_category.topic_id).joins(:tags).where(tags: { id: tag[:id] }) : Topic.none
        base = tag ? "/tags#{Category.find(SiteSetting.svdex_listings_category_id).url}/#{tag[:slug]}/#{tag[:id]}" : nil
        summary = ->(topic) { { id: topic.id, title: topic.title, fancyTitle: topic.fancy_title, url: topic.url, created_at: topic.created_at, like_count: topic.like_count } }
        company = record.facts.except("sector_tag_id", "company_tag_id", *REFERENCE_FACTS, "profile_key_people", "profile_related_entities").symbolize_keys.merge(kind: record.kind, entity_type: record.facts["entity_type"].presence || (record.kind == "funds" ? "fund" : "company"), sector: sector, key_people: references(record, "profile_key_people", guardian), related_entities: references(record, "profile_related_entities", guardian),
          open_offerings: offerings.where(closed: false, archived: false).count, offerings_url: base, open_offerings_url: base && "#{base}?svdex_active=1")
        company[:interest_totals] = CompanyRelationships.totals([record.id], guardian)[record.id] if InterestIndication.totals_visible?(guardian)
        result = { profile: identity(record), company: company,
          discovery: CompanyRelationships.credit(record, guardian), interest_endpoint: "/company-profile-interests/#{record.id}",
          offerings: offerings.order(created_at: :desc).limit(6).map(&summary), updates: updates.order(created_at: :desc).limit(6).map(&summary),
          updates_url: tag && updates_category && guardian.can_see?(updates_category) ? "/tags#{updates_category.url}/#{tag[:slug]}/#{tag[:id]}" : nil }
        if visible_account
          result[:account] = { id: account.id, username: account.username, name: account.name, activity_url: "/u/#{account.username_lower}/activity" }
        end
        result[:correction] = { revision: record.catalog_revision, financials: record.catalog_document["financials"] } if CompanyCatalog.managed?(record)
        result[:editor] = { facts: record.facts, official_username: account&.username, catalog_document: record.catalog_document, catalog_revision: record.catalog_revision } if guardian.is_staff?
        result
      end
      def self.identity(record)
        record.slice(:id, :slug, :name, :summary, :kind).merge(url: record.profile_url, api_path: record.api_path,
          logo_template: record.logo_upload&.url || User.default_template(record.slug), catalog_managed: CompanyCatalog.managed?(record))
      end
      def self.references(record, key, guardian)
        Array(record.facts[key]).filter_map do |entry|
          next unless entry.is_a?(Hash)
          if entry["profile_id"].blank?
            next entry.slice("name", "role", "url").symbolize_keys if entry["name"].present?
            next
          end
          target = CompanyProfileRecord.find_by(id: entry["profile_id"])
          next unless CompanyRelationships.visible?(target, guardian)
          { id: target.id, name: target.name, url: target.profile_url, role: entry["role"].presence,
            avatar_template: target.logo_upload&.url || User.default_template(target.slug) }
        end
      end
      def self.person_payload(record, guardian)
        affiliations = CompanyProfileRecord.where(kind: %w[companies funds]).order(:name).filter_map do |organization|
          next unless CompanyRelationships.visible?(organization, guardian)
          entry = Array(organization.facts["profile_key_people"]).find { |item| item["profile_id"].to_i == record.id }
          next unless entry
          { id: organization.id, name: organization.name, url: organization.profile_url, role: entry["role"].presence,
            avatar_template: organization.logo_upload&.url || User.default_template(organization.slug) }
        end
        data = { profile: identity(record), person: record.facts.slice("role", "focus", "location").symbolize_keys.merge(
          background: record.summary, organizations: affiliations, net_worth: PeopleDirectory.estimate(record.facts)),
          discovery: CompanyRelationships.credit(record, guardian) }
        account = record.official_account
        if account && account.active? && !account.staged? && guardian.public_can_see_profiles? && guardian.can_see_profile?(account)
          data[:account] = { id: account.id, username: account.username, activity_url: "/u/#{account.username_lower}/activity" }
        end
        data[:editor] = { facts: record.facts, official_username: account&.username } if guardian.is_staff?
        data
      end
    end
  end
end
