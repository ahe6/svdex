# frozen_string_literal: true
module DiscourseSvdex
  # Keep native secured lists and Top scoring. Only the list ordering and native
  # Events date-state predicates differ from core's activity-based Latest label.
  module FeedViews
    def self.install!(plugin)
      TopicQuery.add_custom_filter(:svdex_view) { |results, _query| results }
      TopicQuery.add_custom_filter(:svdex_presales) do |results, query|
        value = query.options[:svdex_presales].presence
        raise Discourse::InvalidParameters.new(:svdex_presales) if value && value.to_s != "1"
        if value && Products.category?(query.options[:category_id])
          results.where(category_id: SiteSetting.svdex_presales_category_id)
        else
          results
        end
      end
      plugin.register_modifier(:topic_query_create_list_topics) do |topics, options, query|
        opts = query.options.merge(options)
        category_id = opts[:category_id].to_i
        events = category_id.positive? && category_id == SiteSetting.svdex_events_category_id.to_i
        view = opts[:svdex_view].presence&.to_s
        raise Discourse::InvalidParameters.new(:svdex_view) if view && !%w[latest activity upcoming past].include?(view)
        if events && %w[latest top].include?(opts[:filter].to_s)
          view ||= "upcoming"
          raise Discourse::InvalidParameters.new(:svdex_view) unless %w[upcoming past].include?(view)
          native = DiscourseEvents::Events::TopicsFilter
          topics = native.filter_by_state(topics, view == "past" ? ["past"] : ["upcoming", "ongoing"])
          # Disable native activity pin promotion; event order is chronological.
          options[:order] = "created"
          native.order_by_start(topics.reorder(nil), view == "past" ? "DESC" : "ASC").order("topics.id DESC")
        elsif opts[:filter].to_s == "latest"
          discussion = Category.find_by(id: category_id)&.slug == "discussion"
          view ||= discussion ? "activity" : "latest"
          raise Discourse::InvalidParameters.new(:svdex_view) unless %w[latest activity].include?(view)
          # Explicit native column sorts still work outside the dedicated tabs.
          if opts[:order].blank? && view == "latest"
            options[:order] = "created"
            topics.reorder("topics.created_at DESC, topics.id DESC")
          elsif opts[:order].blank? && view == "activity"
            topics.reorder("topics.bumped_at DESC, topics.id DESC")
          else
            topics
          end
        else
          topics
        end
      end
    end
  end
end
