# frozen_string_literal: true
require "json"
require "digest"
require "date"
require "uri"

module DiscourseSvdex
  module Prototypes
    # Pure public-data format: shared by offline contribution checks and Rails.
    module CatalogDocument
      KEYS = %w[schema_version id name summary company_tag sector stage location financials sources].freeze
      FINANCIAL_KEYS = %w[total_funding_usd last_valuation_usd as_of source_url].freeze
      MAX_MONEY = 9_007_199_254_740_991
      class Invalid < StandardError; end
      class UniqueKeys < Hash
        def []=(key, value)
          raise Invalid, "Duplicate field: #{key}" if key?(key)
          super
        end
      end
      def self.parse(text)
        raise Invalid, "Company file exceeds 64 KB" if text.bytesize > 65_536
        validate!(canonical(JSON.parse(text, object_class: UniqueKeys, max_nesting: 12)))
      rescue JSON::ParserError, JSON::NestingError => error
        raise Invalid, error.message
      end
      def self.exact_keys!(value, keys, label)
        raise Invalid, "Invalid #{label} fields" unless value.is_a?(Hash) && value.keys.sort == keys.sort
      end
      def self.text!(value, limit, label, nullable: false)
        return if nullable && value.nil?
        raise Invalid, "Invalid #{label}" unless value.is_a?(String) && !value.strip.empty? && value == value.strip && value.length <= limit && !value.match?(/[[:cntrl:]]/)
      end
      def self.url!(value)
        uri = URI.parse(value.to_s)
        raise Invalid, "Sources must use public HTTP(S) URLs" unless %w[http https].include?(uri.scheme) && uri.host.to_s.include?(".") && !uri.userinfo && value.length <= 2000
      rescue URI::InvalidURIError
        raise Invalid, "Invalid source URL"
      end
      def self.validate!(doc)
        exact_keys!(doc, KEYS, "company")
        raise Invalid, "Unsupported schema version" unless doc["schema_version"] == 1
        raise Invalid, "Invalid stable company ID" unless doc["id"].is_a?(String) && doc["id"].match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) && doc["id"].length <= 80
        text!(doc["name"], 120, "name")
        text!(doc["summary"], 180, "summary")
        %w[company_tag sector].each { |key| text!(doc[key], 100, key, nullable: true) }
        text!(doc["stage"], 40, "stage", nullable: true)
        text!(doc["location"], 80, "location", nullable: true)
        financials = doc["financials"]
        exact_keys!(financials, FINANCIAL_KEYS, "financial")
        %w[total_funding_usd last_valuation_usd].each do |key|
          value = financials[key]
          next if value.nil?
          raise Invalid, "#{key} must be whole USD or null" unless value.is_a?(Integer) && value.between?(key == "last_valuation_usd" ? 1 : 0, MAX_MONEY)
        end
        if financials["as_of"]
          date = Date.iso8601(financials["as_of"])
          raise Invalid, "Use YYYY-MM-DD for the financial date" unless date.iso8601 == financials["as_of"]
        end
        url!(financials["source_url"]) if financials["source_url"]
        if %w[total_funding_usd last_valuation_usd].any? { |key| !financials[key].nil? }
          raise Invalid, "Known financial figures require an as-of date and source URL" unless financials["as_of"] && financials["source_url"]
        end
        raise Invalid, "Provide 1–8 public sources" unless doc["sources"].is_a?(Array) && doc["sources"].length.between?(1, 8)
        doc["sources"].each do |source|
          exact_keys!(source, %w[url note], "source")
          url!(source["url"])
          text!(source["note"], 180, "source note")
        end
        doc
      rescue ArgumentError, TypeError
        raise Invalid, "Invalid date or field value"
      end
      def self.canonical(value)
        case value
        when Hash then value.keys.sort.to_h { |key| [key, canonical(value[key])] }
        when Array then value.map { |item| canonical(item) }
        else value
        end
      end
      def self.revision(doc)
        Digest::SHA256.hexdigest(JSON.generate(canonical(doc)))
      end
      def self.read_directory(path)
        paths = Dir.glob(File.join(path, "*.json")).sort
        raise Invalid, "Expected 1–500 company files" unless paths.length.between?(1, 500)
        paths.map do |file|
          raise Invalid, "Symbolic company files are not supported" if File.symlink?(file)
          doc = parse(File.read(file))
          raise Invalid, "Filename must match the stable company ID" unless File.basename(file) == "#{doc.fetch('id')}.json"
          doc
        end
      end
    end
  end
end
