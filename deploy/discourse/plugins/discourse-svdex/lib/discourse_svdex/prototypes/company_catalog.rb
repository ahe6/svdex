# frozen_string_literal: true
require_relative "catalog_document"
module DiscourseSvdex
  module Prototypes
    module CompanyCatalog
      FACTS = %w[total_funding_usd last_valuation_usd sector_tag_id company_tag_id stage headquarters_country facts_as_of source_url].freeze
      PROPOSAL_FIELD = "svdex_company_catalog_proposal"
      def self.setup!
        CompanyProfiles.ensure_local!
        c = ActiveRecord::Base.connection
        return if c.column_exists?(CompanyProfileRecord.table_name, :catalog_key)
        c.transaction do
          c.add_column CompanyProfileRecord.table_name, :catalog_key, :string
          c.add_column CompanyProfileRecord.table_name, :catalog_revision, :string
          c.add_column CompanyProfileRecord.table_name, :catalog_document, :jsonb
          c.add_column CompanyProfileRecord.table_name, :catalog_snapshot, :jsonb
          c.add_index CompanyProfileRecord.table_name, :catalog_key, unique: true
        end
      end
      def self.managed?(record)
        record.respond_to?(:catalog_key) && record.catalog_key.present?
      end
      def self.target(doc)
        CompanyProfileRecord.find_by(catalog_key: doc.fetch("id"), kind: "companies") || CompanyProfileRecord.find_by(slug: doc.fetch("id"), kind: "companies") || CompanyProfileRecord.new(slug: doc.fetch("id"), kind: "companies")
      end
      def self.tag_id(name, group, guardian)
        return nil unless name
        tag = CompanyDirectory.tag_options(group, guardian).find { |item| item[:name] == name }
        raise CatalogDocument::Invalid, "Unknown #{group} tag: #{name}" unless tag
        tag[:id]
      end
      def self.attributes(doc, guardian)
        f = doc.fetch("financials")
        facts = { "total_funding_usd" => f["total_funding_usd"], "last_valuation_usd" => f["last_valuation_usd"],
          "sector_tag_id" => tag_id(doc["sector"], "Sectors", guardian), "company_tag_id" => tag_id(doc["company_tag"], "Companies", guardian),
          "stage" => doc["stage"], "headquarters_country" => doc["location"], "facts_as_of" => f["as_of"], "source_url" => f["source_url"] }
        facts = facts.to_h { |key, value| [key, CompanyDirectory.validate!(key, value)] }
        { "name" => doc.fetch("name"), "summary" => doc.fetch("summary"), "facts" => facts }
      end
      def self.snapshot(record)
        { "name" => record.name, "summary" => record.summary, "facts" => FACTS.to_h { |key| [key, record.facts[key]] } }
      end
      def self.import!(documents, actor:, apply: false)
        CompanyProfiles.ensure_local!
        raise Discourse::InvalidAccess unless actor&.staff?
        # Validate all records before any writes. A transaction rolls back the
        # entire batch on conflicts; absent files never delete directory records.
        documents.each { |doc| CatalogDocument.validate!(doc) }
        raise CatalogDocument::Invalid, "Duplicate company IDs" unless documents.map { |doc| doc["id"] }.uniq.length == documents.length
        report = []
        CompanyProfileRecord.transaction(requires_new: true) do
          documents.sort_by { |doc| doc.fetch("id") }.each do |doc|
            record = target(doc)
            record.with_lock do
              raise CatalogDocument::Invalid, "Company ID collision" if managed?(record) && record.catalog_key != doc["id"]
              if managed?(record) && snapshot(record) != record.catalog_snapshot
                raise CatalogDocument::Invalid, "Unreviewed database changes for #{doc['id']}; reconcile before importing"
              end
              values, revision = attributes(doc, Guardian.new(actor)), CatalogDocument.revision(doc)
              changed = record.catalog_revision != revision
              report << { id: doc["id"], changed: changed, before: snapshot(record), after: values }
              next unless apply && changed
              record.assign_attributes(name: values["name"], summary: values["summary"], facts: record.facts.merge(values["facts"]),
                catalog_key: doc["id"], catalog_revision: revision, catalog_document: doc, catalog_snapshot: values)
              record.save!
              StaffActionLogger.new(actor).log_custom("svdex_company_catalog_import", profile_id: record.id, revision: revision)
            end
          end
        end
        report
      end
      def self.reviewer!
        reviewer = User.find_by_username(SiteSetting.svdex_private_access_contact)
        raise Discourse::InvalidParameters.new(:reviewer) unless reviewer&.active? && reviewer.staff?
        reviewer
      end
      def self.suggest!(record, user, input)
        raise Discourse::InvalidAccess unless user&.active? && !user.staged? && !user.suspended?
        raise Discourse::NotFound unless managed?(record)
        raise Discourse::InvalidParameters.new(:revision) unless input["revision"] == record.catalog_revision
        reason = input["reason"].to_s.strip
        raise Discourse::InvalidParameters.new(:reason) unless reason.length.between?(5, 1000)
        proposed = record.catalog_document.deep_dup
        %w[name summary].each { |key| proposed[key] = input[key].to_s.strip if input.key?(key) }
        f = proposed.fetch("financials")
        %w[total_funding_usd last_valuation_usd].each do |key|
          f[key] = CompanyDirectory.validate!(key, input[key]) if input.key?(key)
        end
        %w[as_of source_url].each { |key| f[key] = input[key].presence if input.key?(key) }
        CatalogDocument.validate!(proposed)
        recipient = reviewer!
        raw = suggestion_raw(record, proposed, reason)
        # Match native GroupMembershipRequester: fixed staff-only intake for new
        # accounts, without granting general private-message permissions. Inputs,
        # recipient and rate limits are enforced by this endpoint, not the caller.
        Topic.transaction(requires_new: true) do
          post = PostCreator.create!(user, title: "Company correction: #{record.name}", raw: raw, archetype: Archetype.private_message,
            target_usernames: recipient.username, skip_validations: true)
          post.topic.custom_fields[PROPOSAL_FIELD] = { "company_key" => record.catalog_key, "base_revision" => record.catalog_revision, "document" => proposed }
          post.topic.save_custom_fields
          post.topic
        end
      end
      def self.suggestion_raw(record, proposed, reason)
        changes = []
        { "name" => "Company name", "summary" => "Summary" }.each do |key, label|
          changes << "**#{label}:**\n> #{proposed[key]}" if proposed[key] != record.catalog_document[key]
        end
        { "total_funding_usd" => "Total funding (USD)", "last_valuation_usd" => "Last valuation (USD)", "as_of" => "Financial figures as of", "source_url" => "Financial source" }.each do |key, label|
          value = proposed.fetch("financials")[key]
          next if value == record.catalog_document.fetch("financials")[key]
          display = value.nil? ? "Not specified" : value.to_s
          changes << "**#{label}:**\n> #{display}"
        end
        ["Suggested corrections to **#{record.name.gsub(/[\[\]*`]/, '')}**. Staff review is required before publication.",
          *changes, "**Evidence and requested changes:**\n#{reason.lines.map { |line| '> ' + line }.join}",
          "[View company profile](/company/#{record.slug})"].join("\n\n")
      end
      def self.proposal_document!(topic, actor)
        CompanyProfiles.ensure_local!
        raise Discourse::InvalidAccess unless actor&.staff? && Guardian.new(actor).can_see?(topic)
        raise Discourse::NotFound unless topic.archetype == Archetype.private_message
        proposal = topic.custom_fields[PROPOSAL_FIELD]
        raise Discourse::NotFound unless proposal.is_a?(Hash)
        record = CompanyProfileRecord.find_by!(catalog_key: proposal.fetch("company_key"))
        raise CatalogDocument::Invalid, "This proposal is stale; review it against the current company file" unless record.catalog_revision == proposal["base_revision"]
        doc = CatalogDocument.validate!(proposal.fetch("document"))
        raise CatalogDocument::Invalid, "Company ID changed" unless doc["id"] == record.catalog_key
        doc
      end
    end
  end
end
