# frozen_string_literal: true
# Local feasibility spike. No production migration, route or account conversion.
module DiscourseSvdex
  module Prototypes
    class CompanyProfileRecord < ActiveRecord::Base
      self.table_name = "svdex_company_profile_records"
      belongs_to :official_account, class_name: "User", optional: true
      validates :name, presence: true, length: { maximum: 120 }
      validates :summary, length: { maximum: 180 }
      validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
    end

    module CompanyProfiles
      FACTS = %w[total_funding_usd last_valuation_usd sector_tag_id company_tag_id stage headquarters_country].freeze
      def self.ensure_local!
        raise Discourse::NotFound unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
      end
      def self.setup!
        ensure_local!
        connection = ActiveRecord::Base.connection
        return if connection.data_source_exists?(CompanyProfileRecord.table_name)
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
        CompanyProfileRecord.reset_column_information
      end
    end

    class CompanyProfilesController < ::ApplicationController
      requires_plugin PLUGIN_NAME
      before_action do
        CompanyProfiles.ensure_local!
        raise Discourse::NotFound unless ActiveRecord::Base.connection.data_source_exists?(CompanyProfileRecord.table_name)
      end
      before_action :ensure_staff, only: :update
      skip_before_action :check_xhr, only: :page
      def page
        profile!
        render "default/empty"
      end
      def show
        render_json_dump(payload(profile!))
      end
      def update
        record = profile!
        data = params.require(:profile).permit(:name, :summary, :official_username, facts: CompanyProfiles::FACTS).to_h
        record.with_lock do
          record.name = data["name"] if data.key?("name")
          record.summary = data["summary"] if data.key?("summary")
          if data.key?("official_username")
            account = User.find_by_username(data["official_username"].to_s.strip) if data["official_username"].present?
            raise Discourse::InvalidParameters.new(:official_username) if data["official_username"].present? && (!account&.active? || account.staged?)
            record.official_account = account
          end
          facts = (data["facts"] || {}).to_h { |key, value| [key, CompanyDirectory.validate!(key, value)] }
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
      private
      def profile!
        record = CompanyProfileRecord.find_by!(slug: params[:slug])
        raise Discourse::NotFound unless record.listed || guardian.is_staff?
        record
      end
      def payload(record)
        account = record.official_account
        visible_account = account && account.active? && !account.staged? && guardian.public_can_see_profiles? && guardian.can_see_profile?(account)
        tag = CompanyDirectory.tag_options("Companies", guardian).find { |item| item[:id] == record.facts["company_tag_id"] }
        sector = CompanyDirectory.tag_options("Sectors", guardian).find { |item| item[:id] == record.facts["sector_tag_id"] }
        offerings = tag ? CompanyDirectory.offering_scope(guardian).joins(:tags).where(tags: { id: tag[:id] }).distinct : Topic.none
        updates_category = Category.find_by(id: SiteSetting.svdex_introductions_category_id)
        updates = tag && updates_category && guardian.can_see?(updates_category) ? Topic.visible.secured(guardian).listable_topics.where(category_id: updates_category.id, archetype: Archetype.default).where.not(id: updates_category.topic_id).joins(:tags).where(tags: { id: tag[:id] }) : Topic.none
        base = tag ? "/tags#{Category.find(SiteSetting.svdex_listings_category_id).url}/#{tag[:slug]}/#{tag[:id]}" : nil
        summary = ->(topic) { { id: topic.id, title: topic.title, fancyTitle: topic.fancy_title, url: topic.url, created_at: topic.created_at, like_count: topic.like_count } }
        company = record.facts.except("sector_tag_id", "company_tag_id").symbolize_keys.merge(kind: "companies", entity_type: "company", sector: sector, key_people: [], related_entities: [],
          open_offerings: offerings.where(closed: false, archived: false).count, offerings_url: base, open_offerings_url: base && "#{base}?svdex_active=1")
        result = { profile: record.slice(:slug, :name, :summary), company: company,
          offerings: offerings.order(created_at: :desc).limit(6).map(&summary), updates: updates.order(created_at: :desc).limit(6).map(&summary),
          updates_url: tag && updates_category && guardian.can_see?(updates_category) ? "/tags#{updates_category.url}/#{tag[:slug]}/#{tag[:id]}" : nil }
        if visible_account
          result[:account] = { id: account.id, username: account.username, name: account.name, activity_url: "/u/#{account.username_lower}/activity" }
          if FinancialSubmissions.visible_organization?(account, guardian)
            result[:interest_account] = result[:account]
            result[:company][:interest_totals] = InterestIndication.totals([account.id], guardian)[account.id] if InterestIndication.totals_visible?(guardian)
          end
        end
        result[:editor] = { facts: record.facts, official_username: account&.username } if guardian.is_staff?
        result
      end
    end
  end
end
