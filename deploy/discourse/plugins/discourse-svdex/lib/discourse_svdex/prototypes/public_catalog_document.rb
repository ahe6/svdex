# frozen_string_literal: true
require_relative "catalog_document"
module DiscourseSvdex
  module Prototypes
    module PublicCatalogDocument
      extend self
      FORMAT = "svdex-public-catalog-v1"
      KINDS = %w[companies funds people products].freeze
      KEYS = %w[schema_version id name summary tag sector location facts sources].freeze
      FIELDS = {
        "funds" => %w[aum_usd strategy_focus vintage_year fund_life fund_domicile manager_name facts_as_of source_url],
        "people" => %w[role focus net_worth net_worth_source net_worth_date net_worth_basis],
        "products" => %w[description status price includes delivery],
      }.freeze
      Invalid = CatalogDocument::Invalid
      def validate!(kind, doc)
        raise Invalid, "Unknown catalog kind" unless KINDS.include?(kind)
        return CatalogDocument.validate!(doc) if kind == "companies"
        CatalogDocument.exact_keys!(doc, KEYS, kind)
        raise Invalid, "Unsupported schema version" unless doc["schema_version"] == 1
        raise Invalid, "Invalid stable ID" unless doc["id"].is_a?(String) && doc["id"].match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) && doc["id"].size <= 80
        %w[name summary tag].each { |key| CatalogDocument.text!(doc[key], key == "summary" ? 180 : 120, key) }
        %w[sector location].each { |key| CatalogDocument.text!(doc[key], 100, key, nullable: true) }
        facts = doc["facts"]
        raise Invalid, "Unsupported fact fields" unless facts.is_a?(Hash) && (facts.keys - FIELDS.fetch(kind)).empty?
        facts.each do |key, value|
          next if value.nil?
          if %w[aum_usd vintage_year].include?(key)
            bounds = key == "vintage_year" ? (1800..2500) : (0..CatalogDocument::MAX_MONEY)
            raise Invalid, "Invalid #{key}" unless value.is_a?(Integer) && bounds.cover?(value)
          elsif key == "description"
            raise Invalid, "Invalid product description" unless value.is_a?(String) && value.length.between?(1, 12_000) && !value.match?(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/)
          else
            CatalogDocument.text!(value, 1000, key)
          end
        end
        if kind == "funds"
          date!(facts["facts_as_of"]) if facts["facts_as_of"]
          CatalogDocument.url!(facts["source_url"]) if facts["source_url"]
        end
        if kind == "funds" && !facts["aum_usd"].nil?
          date!(facts["facts_as_of"])
          CatalogDocument.url!(facts["source_url"])
        end
        if kind == "people" && facts.slice(*FIELDS.fetch(kind).grep(/^net_worth/)).values.any? { |v| !v.nil? }
          %w[net_worth net_worth_source net_worth_date net_worth_basis].each { |key| CatalogDocument.text!(facts[key], 1000, key) }
          date!(facts["net_worth_date"])
          CatalogDocument.url!(facts["net_worth_source"])
          raise Invalid, "Net worth needs a public HTTPS source" unless facts["net_worth_source"].start_with?("https://")
        end
        if kind == "products"
          raise Invalid, "Use launched or presales product status" unless %w[launched presales].include?(facts["status"])
          raise Invalid, "Product description required" unless facts["description"]
        end
        raise Invalid, "Provide 1–8 public sources" unless doc["sources"].is_a?(Array) && doc["sources"].length.between?(1, 8)
        doc["sources"].each do |source|
          CatalogDocument.exact_keys!(source, %w[url note], "source")
          CatalogDocument.url!(source["url"])
          CatalogDocument.text!(source["note"], 180, "source note")
        end
        doc
      end
      def date!(value)
        raise Invalid, "Use YYYY-MM-DD" unless value.is_a?(String) && Date.iso8601(value).iso8601 == value
      rescue ArgumentError
        raise Invalid, "Use YYYY-MM-DD"
      end
      def bundle(directory)
        entries = KINDS.flat_map do |kind|
          Dir.glob(File.join(directory, kind, "*.json")).sort.map do |path|
            raise Invalid, "Symbolic content files are not supported" if File.symlink?(path) || File.symlink?(File.dirname(path))
            raise Invalid, "Content file exceeds 64 KB" if File.size(path) > 65_536
            doc = CatalogDocument.canonical(JSON.parse(File.read(path), object_class: CatalogDocument::UniqueKeys, max_nesting: 12))
            validate!(kind, doc)
            raise Invalid, "Filename must match stable ID" unless File.basename(path) == "#{doc.fetch('id')}.json"
            { "kind" => kind, "document" => doc }
          end
        end
        validate_bundle!({ "format" => FORMAT, "entries" => entries })
      rescue JSON::ParserError => error
        raise Invalid, error.message
      end
      def validate_bundle!(data)
        CatalogDocument.exact_keys!(data, %w[format entries], "bundle")
        raise Invalid, "Invalid catalog bundle" unless data["format"] == FORMAT && data["entries"].is_a?(Array) && data["entries"].length.between?(1, 2000)
        keys = data["entries"].map do |entry|
          CatalogDocument.exact_keys!(entry, %w[kind document], "entry")
          validate!(entry["kind"], entry["document"])
          [entry["kind"], entry["document"]["id"]]
        end
        raise Invalid, "Duplicate entity IDs" unless keys.uniq == keys
        data
      end
    end
  end
end
