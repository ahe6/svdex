# frozen_string_literal: true
module DiscourseSvdex
  # Native discovery query/serializer extensions. Registration stays ordered;
  # filtering remains server-side and always builds on Guardian's secured scope.
  module TopicDiscovery
    # Run after the feed modifiers so the total includes the native Events date filter.
    def self.install_catalog_counts!(plugin)
      plugin.register_modifier(:topic_query_create_list_topics) do |topics, options, query|
        category_id = query.options.merge(options)[:category_id]
        field = catalog_count_field(category_id)
        next topics unless field

        # Count the secured relation before pagination and pin promotion.
        matching = topics.except(:limit, :offset, :order).reselect("topics.id").distinct
        if DiscourseSvdex.offering_category?(category_id) || Presales.category?(category_id)
          matching = matching.where(topics: { closed: false, archived: false })
        end
        total = Topic.unscoped.from(matching, :svdex_matching_topics).count
        topics = topics.select("topics.*") if topics.select_values.empty?
        topics.select("#{Integer(total)} AS #{field}")
      end

      %i[svdex_offering_count svdex_catalog_count].each do |field|
        plugin.add_to_serializer(:topic_list, field, include_condition: -> {
          TopicDiscovery.catalog_count_field(object.category&.id) == field
        }) { object.topics.first&.attributes&.fetch(field.to_s, 0).to_i }
      end
    end

    def self.catalog_count_field(id)
      return :svdex_offering_count if DiscourseSvdex.offering_category?(id)
      if id.to_i.positive? && (Products.category?(id) || Presales.category?(id) || id.to_i == SiteSetting.svdex_events_category_id.to_i)
        :svdex_catalog_count
      end
    end

    def self.home_topics(topics)
      feedback = SiteSetting.svdex_help_category_id.to_i
      feedback = SiteSetting.meta_category_id.to_i unless feedback.positive?
      topics.where.not(category_id: feedback)
        .where.not(id: Category.where.not(topic_id: nil).select(:topic_id))
    end

    def self.install!(plugin)
      plugin.instance_eval do
      # Exclude Feedback and category descriptions from the already secured Home
      # query before pagination. Scoped category and standalone tag lists remain native.
      register_modifier(:topic_query_create_list_topics) do |topics, options, query|
        opts = query.options.merge(options)
        scoped = %i[category category_id tags tag_id username group_name topic_ids].any? { |key| opts[key].present? }
        if %w[latest top].include?(opts[:filter].to_s) && !scoped
          TopicDiscovery.home_topics(topics)
        else
          topics
        end
      end

      # Home's tag selector keeps the same exclusion as the unfiltered feed.
      TopicQuery.add_custom_filter(:svdex_home) do |results, query|
        if query.options[:svdex_home].to_s == "1"
          TopicDiscovery.home_topics(results)
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
