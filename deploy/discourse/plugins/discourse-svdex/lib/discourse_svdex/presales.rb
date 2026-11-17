# frozen_string_literal: true
module DiscourseSvdex
  # Product pre-orders share presentation with Offerings, never securities data,
  # financial interest, bids, ownership permissions or offering visibility tags.
  module Presales
    FIELDS = { "summary" => 180, "price" => 80, "includes" => 120, "delivery" => 80, "terms" => 240 }.freeze
    def self.category?(id)
      id.to_i > 0 && id.to_i == SiteSetting.svdex_presales_category_id.to_i
    end
    def self.topic?(topic)
      category?(topic.category_id) && topic.archetype == Archetype.default &&
        topic.id != Category.find_by(id: topic.category_id)&.topic_id
    end
    def self.validate!(key, value)
      raise Discourse::InvalidParameters.new(key) unless value.is_a?(String) && value.length <= FIELDS.fetch(key)
      value.strip
    end
    def self.install!(plugin)
      plugin.instance_eval do
        Presales::FIELDS.each do |key, length|
          name = "svdex_presale_#{key}"
          register_topic_custom_field_type(name, :string, max_length: length)
          add_preloaded_topic_list_custom_field(name)
          add_permitted_post_create_param(name.to_sym)
          NewPostManager.add_plugin_payload_attribute(name.to_sym)
          add_permitted_post_update_param(name.to_sym) do |post, value|
            next if value.nil?
            raise Discourse::InvalidParameters.new(name) unless post.is_first_post? && Presales.topic?(post.topic)
            Presales.validate!(key, value)
          end
          PostRevisor.track_topic_field(name.to_sym) do |changes, value|
            next if value.nil? || !Presales.topic?(changes.topic)
            validated = Presales.validate!(key, value)
            changes.record_change(name, changes.topic.custom_fields[name], validated)
            changes.topic.custom_fields[name] = validated
          end
        end
        ReviewableQueuedPostSerializer.payload_attributes(*Presales::FIELDS.keys.map { |key| "svdex_presale_#{key}" })
        on(:before_create_topic) do |topic, creator|
          supplied = Presales::FIELDS.keys.select { |key| creator.opts.key?("svdex_presale_#{key}".to_sym) }
          raise Discourse::InvalidParameters.new(:category) if supplied.any? && !Presales.category?(topic.category_id)
          supplied.each { |key| topic.custom_fields["svdex_presale_#{key}"] = Presales.validate!(key, creator.opts["svdex_presale_#{key}".to_sym]) }
        end
        [:topic_list_item, :topic_view].each do |serializer|
          add_to_serializer(serializer, :svdex_presale, include_condition: -> { Presales.topic?(object.respond_to?(:topic) ? object.topic : object) }) do
            topic = object.respond_to?(:topic) ? object.topic : object
            Presales::FIELDS.keys.to_h { |key| [key, topic.custom_fields["svdex_presale_#{key}"].to_s] }
          end
        end
        TopicQuery.add_custom_filter(:svdex_presale_rows) do |results, query|
          if Presales.category?(query.options[:category_id])
            results.where.not(id: Category.where(id: SiteSetting.svdex_presales_category_id).where.not(topic_id: nil).select(:topic_id))
          else
            results
          end
        end
      end
    end
  end
end
