# frozen_string_literal: true

module DiscourseSvdex
  module Prototypes
    module TopicLogos
      def self.install!(plugin)
        Topic.attr_accessor :svdex_organization_logo

        TopicList.on_preload do |topics, _list|
          candidates = topics.select do |topic|
            topic.archetype == Archetype.default &&
              (DiscourseSvdex.offering_category?(topic.category_id) ||
                Products.category?(topic.category_id) || Presales.category?(topic.category_id))
          end
          next if candidates.empty? || !CompanyProfileRecord.table_exists?

          source_ids = logo_source_ids(candidates)
          tags_by_topic = TopicTag.where(topic_id: source_ids.values.uniq).pluck(:topic_id, :tag_id).group_by(&:first)
          tag_ids = tags_by_topic.values.flatten(1).map(&:last).uniq
          next if tag_ids.empty?

          profiles = CompanyProfileRecord.where(listed: true, kind: %w[companies funds])
            .where("facts->>'company_tag_id' IN (?)", tag_ids.map(&:to_s))
            .includes(:logo_upload).group_by { |profile| profile.facts["company_tag_id"].to_i }

          candidates.each do |topic|
            matches = tags_by_topic.fetch(source_ids.fetch(topic.id), []).flat_map { |_, tag_id| profiles.fetch(tag_id, []) }.uniq
            next unless matches.one?

            logo = matches.first.logo_upload
            topic.svdex_organization_logo = logo.url if logo && !logo.secure?
          end
        end

        plugin.add_to_serializer(:topic_list_item, :svdex_organization_logo,
          include_condition: -> { object.svdex_organization_logo.present? }) do
          object.svdex_organization_logo
        end
      end

      def self.logo_source_ids(topics)
        linked = topics.select { |topic| Presales.category?(topic.category_id) }.to_h do |topic|
          [topic.id, topic.preloaded_custom_fields[Presales::PRODUCT_FIELD]]
        end
        product_ids = linked.values.compact.uniq
        visible = product_ids.empty? ? Set.new : Presales.public_products.where(id: product_ids).pluck(:id).to_set
        topics.to_h do |topic|
          product_id = linked[topic.id]
          [topic.id, visible.include?(product_id) ? product_id : topic.id]
        end
      end
    end
  end
end
