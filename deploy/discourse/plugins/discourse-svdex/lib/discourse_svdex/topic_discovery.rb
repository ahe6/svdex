# frozen_string_literal: true
module DiscourseSvdex
  # Native discovery query/serializer extensions. Registration stays ordered;
  # filtering remains server-side and always builds on Guardian's secured scope.
  module TopicDiscovery
    def self.install!(plugin)
      plugin.instance_eval do
      # Home is a discovery feed for offerings and approved company/fund updates,
      # including introductions. Discussions and Help remain readable in their own
      # categories, search, bookmarks, notifications and direct links. Apply the
      # allowlist before pagination rather than hiding fetched topics in the UI.
      # Native Guardian filtering still protects private offering categories.
      register_modifier(:topic_query_create_list_topics) do |topics, options, query|
        opts = query.options.merge(options)
        scoped = %i[category category_id tags tag_id username group_name topic_ids].any? { |key| opts[key].present? }
        if %w[latest top].include?(opts[:filter].to_s) && !scoped
          topics.where(category_id: DiscourseSvdex.home_category_ids)
            .where.not(id: Category.where(id: DiscourseSvdex.home_category_ids).where.not(topic_id: nil).select(:topic_id))
        else
          topics
        end
      end

      # Count the secured, fully filtered relation before pagination and native
      # pinning split it into separate queries. Attach that same total to each row.
      register_modifier(:topic_query_create_list_topics) do |topics, options, query|
        if DiscourseSvdex.offering_category?(query.options.merge(options)[:category_id])
          matching = topics.except(:limit, :offset, :order).reselect("topics.id").distinct
          total = Topic.unscoped.from(matching, :svdex_matching_offerings).count
          topics = topics.select("topics.*") if topics.select_values.empty?
          topics.select("#{Integer(total)} AS svdex_offering_count")
        else
          topics
        end
      end
      add_to_serializer(:topic_list, :svdex_offering_count, include_condition: -> {
        DiscourseSvdex.offering_category?(object.category&.id)
      }) { object.topics.first&.attributes&.fetch("svdex_offering_count", 0).to_i }

      # The native description topic is category documentation, never a listing,
      # including for staff who can otherwise see unlisted topics.
      # Home's native tag selector narrows the existing feed, not the global tag
      # directory. The marker preserves that allowlist through tag filtering.
      TopicQuery.add_custom_filter(:svdex_home) do |results, query|
        if query.options[:svdex_home].to_s == "1"
          results.where(category_id: DiscourseSvdex.home_category_ids)
            .where.not(id: Category.where(id: DiscourseSvdex.home_category_ids).where.not(topic_id: nil).select(:topic_id))
        else
          results
        end
      end

      TopicQuery.add_custom_filter(:svdex_listing_rows) do |results, query|
        if DiscourseSvdex.offering_category?(query.options[:category_id])
          description_ids = Category.where(id: DiscourseSvdex.offering_category_ids).where.not(topic_id: nil).pluck(:topic_id)
          results.where.not(id: description_ids)
        else
          results
        end
      end

      TopicQuery.add_custom_filter(:svdex_active) do |results, query|
        query.options[:svdex_active].to_s == "1" ? results.where(closed: false, archived: false) : results
      end

      TopicQuery.add_custom_filter(:svdex_company) do |results, query|
        value = query.options[:svdex_company]
        if value.present? && DiscourseSvdex.offering_category?(query.options[:category_id])
          raise Discourse::InvalidParameters.new(:svdex_company) unless value.is_a?(String) && value.length <= 120
          company = value.strip.split(" — ", 2).first
          results.where("(#{DiscourseSvdex::COMPANY_NAME_SQL} ILIKE :company OR topics.title ILIKE :offering)",
            company: "%#{ActiveRecord::Base.sanitize_sql_like(company)}%",
            offering: "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%")
        else
          results
        end
      end

      TopicQuery.add_custom_filter(:svdex_valuation) do |results, query|
        value = query.options[:svdex_valuation]
        if value.present? && DiscourseSvdex.offering_category?(query.options[:category_id])
          ranges = { "under-10m" => [1, 10_000_000], "10m-50m" => [10_000_000, 50_000_000],
                     "50m-250m" => [50_000_000, 250_000_000], "250m-plus" => [250_000_000, nil] }
          raise Discourse::InvalidParameters.new(:svdex_valuation) unless ranges.key?(value) || value == "undisclosed"
          amount = "CASE WHEN value ~ '^[0-9]+$' THEN value::numeric ELSE NULL END"
          known = TopicCustomField.where(name: DiscourseSvdex::VALUATION_FIELD).where("#{amount} > 0")
          if value == "undisclosed"
            results.where.not(id: known.select(:topic_id))
          else
            lower, upper = ranges.fetch(value)
            matching = known.where("#{amount} >= ?", lower)
            matching = matching.where("#{amount} < ?", upper) if upper
            results.where(id: matching.select(:topic_id))
          end
        else
          results
        end
      end
      end
    end
  end
end
