# frozen_string_literal: true
# Loaded only by the localhost:4080 experiment. Native submission and audit tables
# remain authoritative; explicit company references never borrow a User ID.
module DiscourseSvdex
  module Prototypes
    module CompanyRelationships
      def self.ready?
        ActiveRecord::Base.connection.column_exists?(:svdex_interest_indications, :company_profile_id)
      end
      def self.setup!
        CompanyProfiles.ensure_local!
        c = ActiveRecord::Base.connection
        c.transaction do
          unless ready?
            c.add_column :svdex_interest_indications, :company_profile_id, :bigint
            c.change_column_null :svdex_interest_indications, :organization_id, true
            c.add_foreign_key :svdex_interest_indications, CompanyProfileRecord.table_name, column: :company_profile_id, on_delete: :restrict
            c.add_index :svdex_interest_indications, [:user_id, :company_profile_id, :side], unique: true, name: "svdex_interest_company_profile"
            c.add_check_constraint :svdex_interest_indications, "num_nonnulls(organization_id, company_profile_id) = 1", name: "svdex_interest_one_target"
            c.add_column :svdex_discoveries, :company_profile_id, :bigint
            c.add_column :svdex_discoveries, :original_company_profile_id, :bigint
            c.change_column_null :svdex_discoveries, :original_entity_user_id, true
            c.add_foreign_key :svdex_discoveries, CompanyProfileRecord.table_name, column: :company_profile_id, on_delete: :restrict
            c.add_index :svdex_discoveries, :company_profile_id, unique: true, where: "superseded_by_id IS NULL", name: "svdex_discovery_company_profile"
            c.add_check_constraint :svdex_discoveries, "num_nonnulls(original_entity_user_id, original_company_profile_id) = 1", name: "svdex_discovery_one_original_target"
          end
        end
        InterestIndication.reset_column_information
        Discovery.reset_column_information
      end
      def self.install!
        InterestIndication.belongs_to :company_profile, class_name: "DiscourseSvdex::Prototypes::CompanyProfileRecord", optional: true
        InterestIndication.validates :user_id, uniqueness: { scope: [:company_profile_id, :side] }, if: -> { respond_to?(:company_profile_id) && company_profile_id.present? }
        Discovery.belongs_to :company_profile, class_name: "DiscourseSvdex::Prototypes::CompanyProfileRecord", optional: true
        Discovery.attr_readonly :original_company_profile_id
        Discoveries.singleton_class.prepend(CompanyDiscoveryHistory)
        MyInterestController.prepend(CompanySubmissionHistory)
      end
      def self.visible?(record, guardian)
        record && (record.listed || guardian.is_staff?)
      end
      def self.totals(ids, guardian)
        return {} unless ready? && InterestIndication.totals_visible?(guardian)
        InterestIndication.aggregate_scope(guardian).where(company_profile_id: ids).group(:company_profile_id, :side)
          .pluck(:company_profile_id, :side, Arel.sql("COALESCE(SUM(CASE WHEN withdrawn_at IS NULL AND expires_at > CURRENT_TIMESTAMP THEN amount_cents ELSE 0 END), 0)"))
          .each_with_object({}) { |(id, side, amount), result| (result[id] ||= {})[side] = amount.to_i }
      end
      def self.credit(record, guardian)
        return unless ready? && visible?(record, guardian)
        row = Discovery.find_by(company_profile_id: record.id, superseded_by_id: nil, status: "accepted")
        return unless row
        data = { provenance: row.provenance, listed_at: row.listed_at&.iso8601 }
        if Discoveries::CREDITED.include?(row.provenance)
          return unless Discoveries.visible?(row.contributor, guardian)
          data[:contributor] = BasicUserSerializer.new(row.contributor, scope: guardian, root: false).as_json
        end
        data
      end
      def self.record_discovery!(record, actor, attrs)
        raise Discourse::InvalidAccess unless actor&.staff?
        reason = attrs["reason"].to_s.strip
        raise Discourse::InvalidParameters.new(:reason) unless reason.length.between?(5, 1000)
        record.with_lock do
          row = Discovery.find_or_initialize_by(company_profile_id: record.id, superseded_by_id: nil)
          before = row.persisted? ? row.attributes : {}
          provenance = attrs.fetch("provenance", row.provenance)
          status = attrs.fetch("status", row.status)
          raise Discourse::InvalidParameters.new(:provenance) unless %w[discovered self_listed staff_added imported].include?(provenance)
          raise Discourse::InvalidParameters.new(:status) unless %w[accepted withdrawn disputed].include?(status)
          contributor = User.find_by_username(attrs["contributor"].to_s) if Discoveries::CREDITED.include?(provenance)
          if Discoveries::CREDITED.include?(provenance)
            raise Discourse::InvalidParameters.new(:contributor) unless contributor&.active? && !contributor.staged?
            raise Discourse::InvalidParameters.new(:contributor) if provenance == "discovered" && contributor.id == record.official_account_id
            raise Discourse::InvalidParameters.new(:contributor) if provenance == "self_listed" && contributor.id != record.official_account_id
          end
          date = row.listed_at
          if attrs["listed_at"].present?
            begin
              supplied = Time.iso8601(attrs["listed_at"])
            rescue ArgumentError
              raise Discourse::InvalidParameters.new(:listed_at)
            end
            raise Discourse::InvalidParameters.new(:listed_at) if supplied > Time.current || supplied < record.created_at || (date && supplied.to_i != date.to_i)
            date ||= supplied
          end
          raise Discourse::InvalidParameters.new(:listed_at) if contributor && date.nil?
          raise Discourse::InvalidParameters.new(:profile) if contributor && status == "accepted" && record.summary.to_s.strip.length < 20
          row.assign_attributes(entity_kind: "companies", original_company_profile_id: record.id, provenance: provenance, status: status, contributor_user_id: contributor&.id, listed_at: date)
          row.original_contributor_user_id ||= contributor&.id
          row.save!
          Discoveries.event!(row, actor, "reviewed", reason, before)
          StaffActionLogger.new(actor).log_custom("svdex_company_discovery_review", profile_id: record.id, discovery_id: row.id, reason: reason)
          row
        end
      end
      def self.discovery_payload(record)
        row = Discovery.find_by(company_profile_id: record.id, superseded_by_id: nil)
        { eligible: true, discovery: row && { provenance: row.provenance, status: row.status, contributor: row.contributor&.username, listed_at: row.listed_at&.iso8601 },
          events: row ? DiscoveryEvent.where(discovery_id: row.id).order(id: :desc).limit(50).map { |event| event.attributes.merge("label" => event.action.humanize) } : [] }
      end
    end

    class CompanyInterestsController < InterestsController
      before_action { CompanyProfiles.ensure_local!; raise Discourse::NotFound unless CompanyRelationships.ready? }
      private
      def organization!
        record = CompanyProfileRecord.find_by(id: params[:organization_id])
        raise Discourse::NotFound unless CompanyRelationships.visible?(record, guardian)
        record
      end
      def target_scope(record)
        InterestIndication.where(company_profile_id: record.id)
      end
      def target_totals(record)
        CompanyRelationships.totals([record.id], guardian)[record.id]
      end
      def offering!(_record, _id)
        # This slice is company-wide interest only; bids keep their native path.
        raise Discourse::InvalidParameters.new(:topic_id)
      end
    end

    module CompanySubmissionHistory
      private
      def payload(kind, row)
        return super unless kind == "interest" && row.respond_to?(:company_profile_id) && row.company_profile_id
        record = row.company_profile
        accessible = CompanyRelationships.visible?(record, guardian)
        { id: row.id, kind: kind, status: FinancialSubmissions.state(row), amount_cents: row.amount_cents, currency: row.currency,
          updated_at: row.updated_at, expires_at: row.expires_at, withdrawn_at: row.withdrawn_at, side: row.side, market: row.market,
          organization: accessible ? { id: record.id, name: record.name, url: "/company/#{record.slug}", interest_endpoint: "/company-profile-interests/#{record.id}" } : nil,
          topic: nil, proposed_terms: nil, can_edit: !!(accessible && SiteSetting.svdex_interest_enabled) }
      end
    end

    module CompanyDiscoveryHistory
      def additional_history(user, guardian, type: nil)
        entries = super
        return entries unless CompanyRelationships.ready? && (type.nil? || type == "companies")
        rows = Discovery.where(contributor_user_id: user.id, entity_kind: "companies", provenance: "discovered", status: "accepted", superseded_by_id: nil).where.not(company_profile_id: nil).includes(:company_profile)
        entries + rows.filter_map do |row|
          record = row.company_profile
          next unless CompanyRelationships.visible?(record, guardian)
          { id: row.id, entity: { name: record.name }, kind: "companies", background: record.summary, provenance: row.provenance, listed_at: row.listed_at.iso8601, url: "/company/#{record.slug}" }
        end
      end
    end
  end
end
