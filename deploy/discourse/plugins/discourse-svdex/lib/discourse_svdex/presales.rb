# frozen_string_literal: true
module DiscourseSvdex
  # Product pre-orders share presentation with Offerings, never securities data,
  # financial interest, bids, ownership permissions or offering visibility tags.
  module Presales
    FIELDS = { "summary" => 180, "price" => 80, "includes" => 120, "delivery" => 80, "terms" => 240 }.freeze
    PRODUCT_FIELD = "svdex_presale_product_id"

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

    def self.public_products
      category = Category.find_by(id: SiteSetting.svdex_products_category_id, read_restricted: false)
      return Topic.none unless category && Guardian.new.can_see?(category)

      Topic.where(category_id: category.id, visible: true, archetype: Archetype.default).where.not(id: category.topic_id)
    end

    def self.public_product(id)
      return unless id.to_s.match?(/\A[1-9][0-9]{0,9}\z/)

      public_products.find_by(id: id)
    end

    def self.product_message
      I18n.t("svdex.presales.product_required")
    end

    def self.install!(plugin)
      plugin.instance_eval do
        product_field = Presales::PRODUCT_FIELD
        register_topic_custom_field_type(product_field, :integer)
        add_preloaded_topic_list_custom_field(product_field)
        add_permitted_post_create_param(product_field.to_sym)
        NewPostManager.add_plugin_payload_attribute(product_field.to_sym)
        ReviewableQueuedPostSerializer.payload_attributes(product_field)
        NewPostManager.add_handler do |manager|
          args = manager.args
          next if args[:topic_id].present? || !Presales.category?(args[:category])
          next if Presales.public_product(args[Presales::PRODUCT_FIELD.to_sym])

          NewPostResult.new(:created_post).tap { |result| result.errors.add(:base, Presales.product_message) }
        end
        add_permitted_post_update_param(product_field.to_sym) do |post, value|
          next if value.nil?
          raise Discourse::InvalidParameters.new(product_field) unless post.is_first_post? && Presales.topic?(post.topic)
          # Existing campaigns without a link can still be edited and repaired.
          next if value == "" && !Presales.public_product(post.topic.custom_fields[product_field])
          raise Discourse::InvalidParameters.new(Presales.product_message) unless Presales.public_product(value)
        end
        PostRevisor.track_topic_field(product_field.to_sym) do |changes, value|
          next if value.blank? || !Presales.topic?(changes.topic)

          product = Presales.public_product(value)
          raise Discourse::InvalidParameters.new(Presales.product_message) unless product
          changes.record_change(product_field, changes.topic.custom_fields[product_field], product.id)
          changes.topic.custom_fields[product_field] = product.id
        end

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
          product_key = Presales::PRODUCT_FIELD.to_sym
          unless Presales.category?(topic.category_id)
            raise Discourse::InvalidParameters.new(:category) if supplied.any? || creator.opts.key?(product_key)
            next
          end
          product = Presales.public_product(creator.opts[product_key])
          raise Discourse::InvalidParameters.new(Presales.product_message) unless product
          topic.custom_fields[Presales::PRODUCT_FIELD] = product.id
          supplied.each { |key| topic.custom_fields["svdex_presale_#{key}"] = Presales.validate!(key, creator.opts["svdex_presale_#{key}".to_sym]) }
        end
        [:topic_list_item, :topic_view].each do |serializer|
          add_to_serializer(serializer, :svdex_presale, include_condition: -> { Presales.topic?(object.respond_to?(:topic) ? object.topic : object) }) do
            topic = object.respond_to?(:topic) ? object.topic : object
            fields = Presales::FIELDS.keys.to_h { |key| [key, topic.custom_fields["svdex_presale_#{key}"].to_s] }
            if product = Presales.public_product(topic.custom_fields[Presales::PRODUCT_FIELD])
              fields["product_id"] = product.id
              fields["product_title"] = product.title if serializer == :topic_view
            end
            fields
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
