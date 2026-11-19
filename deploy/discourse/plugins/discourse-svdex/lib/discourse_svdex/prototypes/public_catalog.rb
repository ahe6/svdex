# frozen_string_literal: true
require_relative "public_catalog_document"
module DiscourseSvdex
  module Prototypes
    module PublicCatalog
      extend self
      Invalid = CatalogDocument::Invalid
      PRODUCT_KEY = "svdex_catalog_product_key"
      PRODUCT_STATE = "svdex_public_catalog"
      def ready!
        raise Invalid, "Independent profile backend must be installed before content sync" unless defined?(CompanyProfileRecord) && ActiveRecord::Base.connection.column_exists?(CompanyProfileRecord.table_name, :catalog_snapshot)
      end
      def import!(bundle, actor:, apply: false)
        ready!
        raise Discourse::InvalidAccess unless actor&.active? && actor.staff?
        PublicCatalogDocument.validate_bundle!(bundle)
        reports = []
        CompanyProfileRecord.transaction(requires_new: true) do
          # All content imports serialize, including separate processes.
          ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(738439, 1)")
          bundle.fetch("entries").sort_by { |e| [e["kind"], e["document"]["id"]] }.each do |entry|
            kind, doc = entry.values_at("kind", "document")
            result = kind == "products" ? product!(doc, actor, dry_run: !apply) : profile!(kind, doc, actor)
            reports << { kind: kind, id: doc["id"], changed: result }
          end
          raise ActiveRecord::Rollback unless apply
        end
        reports
      end
      def tag!(name, group_name)
        return nil unless name
        tag = Tag.find_by(name: name)
        if tag && !DiscourseTagging.visible_tags(Guardian.new).where(id: tag.id).exists?
          raise Invalid, "Content cannot claim a restricted tag"
        end
        tag ||= Tag.create!(name: name)
        group = TagGroup.find_by_name_insensitive(group_name) || TagGroup.create!(name: group_name)
        group.tags << tag unless group.tags.exists?(tag.id)
        raise Invalid, "Content tags must be public" unless DiscourseTagging.visible_tags(Guardian.new).where(id: tag.id).exists?
        tag
      end
      def profile!(kind, doc, actor)
        legacy = kind == "companies"
        tag = tag!(legacy ? doc["company_tag"] : doc["tag"], kind == "people" ? "People" : "Companies")
        sector = tag!(doc["sector"], "Sectors")
        values = if legacy
          CompanyCatalog.attributes(doc, Guardian.new(actor))
        else
          facts = PublicCatalogDocument::FIELDS.fetch(kind).to_h { |key| [key, doc["facts"][key]] }
          if kind == "people"
            facts.merge!("location" => doc["location"], "topic_tag_id" => tag&.id)
            if facts["net_worth"] && PeopleDirectory.estimate(facts).nil?
              raise Invalid, "Invalid sourced net-worth estimate"
            end
          else
            facts.merge!("headquarters_country" => doc["location"], "company_tag_id" => tag&.id, "sector_tag_id" => sector&.id)
            facts.each { |key, value| CompanyDirectory.validate!(key, value) unless %w[sector_tag_id company_tag_id].include?(key) }
          end
          { "name" => doc["name"], "summary" => doc["summary"], "facts" => facts }
        end
        key = legacy ? doc["id"] : "#{kind}/#{doc['id']}"
        record = CompanyProfileRecord.find_by(catalog_key: key) || CompanyProfileRecord.find_by(slug: doc["id"], kind: kind) || CompanyProfileRecord.new(slug: doc["id"], kind: kind, listed: true)
        record.with_lock do
          raise Invalid, "Profile identity collision" unless record.kind == kind && (!record.catalog_key || record.catalog_key == key)
          snapshot = legacy ? CompanyCatalog.snapshot(record) : profile_snapshot(record, values["facts"].keys)
          raise Invalid, "Database edits conflict with reviewed content: #{key}" if record.catalog_key && snapshot != record.catalog_snapshot
          revision = CatalogDocument.revision(doc)
          return false if record.catalog_revision == revision
          record.assign_attributes(name: values["name"], summary: values["summary"], facts: record.facts.merge(values["facts"]), catalog_key: key, catalog_revision: revision, catalog_document: doc, catalog_snapshot: values)
          record.save!
          StaffActionLogger.new(actor).log_custom("svdex_public_catalog_import", kind: kind, profile_id: record.id, revision: revision)
        end
        true
      end
      def profile_snapshot(record, keys)
        { "name" => record.name, "summary" => record.summary, "facts" => record.facts.slice(*keys) }
      end
      def product_snapshot(topic)
        { "name" => topic.title, "category_id" => topic.category_id, "raw" => topic.first_post.raw,
          "tags" => topic.tags.pluck(:name).sort,
          "fields" => topic.custom_fields.slice(*Presales::FIELDS.keys.map { |key| "svdex_presale_#{key}" }) }
      end
      def product!(doc, actor, dry_run: false)
        tag = tag!(doc["tag"], "Products")
        sector = tag!(doc["sector"], "Sectors")
        category_id = doc["facts"]["status"] == "presales" ? SiteSetting.svdex_presales_category_id : SiteSetting.svdex_products_category_id
        category = Category.find(category_id)
        raise Invalid, "Products catalog only publishes to public product categories" if category.read_restricted?
        row = TopicCustomField.find_by(name: PRODUCT_KEY, value: doc["id"])
        topic = row&.topic
        revision = CatalogDocument.revision(doc)
        raw = [doc["summary"], doc["facts"]["description"]].join("\n\n")
        %w[price includes delivery].each { |key| Presales.validate!(key, doc["facts"][key].to_s) }
        values = { title: doc["name"], raw: raw, category_id: category.id, tags: [tag.name, sector&.name].compact }
        if topic
          topic.lock!
          state = topic.custom_fields[PRODUCT_STATE]
          raise Invalid, "Product content ownership is missing" unless state.is_a?(Hash)
          raise Invalid, "Database edits conflict with reviewed product content" unless state["snapshot"] == product_snapshot(topic)
          return false if state["revision"] == revision
          return true if dry_run
          raise Invalid, "Native product revision failed" unless PostRevisor.new(topic.first_post).revise!(actor, values, skip_validations: true, bypass_bump: true)
        else
          return true if dry_run
          topic = PostCreator.create!(actor, values.merge(category: category.id, skip_validations: true, skip_jobs: true)).topic
        end
        topic.custom_fields[PRODUCT_KEY] = doc["id"]
        { "svdex_presale_summary" => doc["summary"], "svdex_presale_price" => doc["facts"]["price"], "svdex_presale_includes" => doc["facts"]["includes"], "svdex_presale_delivery" => doc["facts"]["delivery"] }.each { |key, value| topic.custom_fields[key] = value }
        topic.save_custom_fields
        topic.custom_fields[PRODUCT_STATE] = { "revision" => revision, "snapshot" => product_snapshot(topic) }
        topic.save_custom_fields
        StaffActionLogger.new(actor).log_custom("svdex_product_catalog_import", topic_id: topic.id, revision: revision)
        true
      end
    end
  end
end
