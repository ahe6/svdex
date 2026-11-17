# frozen_string_literal: true
module DiscourseSvdex
  # A product is a lasting native topic, not a security or a pre-sale campaign.
  # Its description, links, edit history and moderation stay in the native post.
  module Products
    def self.category?(id)
      id.to_i > 0 && id.to_i == SiteSetting.svdex_products_category_id.to_i
    end

    def self.topic?(topic)
      category?(topic.category_id) && topic.archetype == Archetype.default &&
        topic.id != Category.find_by(id: topic.category_id)&.topic_id
    end

    def self.install!(plugin)
      plugin.instance_eval do
        add_to_serializer(:topic_list_item, :svdex_product, include_condition: -> { Products.topic?(object) }) do
          # Use the cached native excerpt, with no per-row first-post lookup.
          text = ActionView::Base.full_sanitizer.sanitize(object.excerpt.to_s)
          { summary: CGI.unescapeHTML(text).lines.first.to_s.squish.truncate(180) }
        end
        TopicQuery.add_custom_filter(:svdex_product_rows) do |results, query|
          if Products.category?(query.options[:category_id])
            ids = [SiteSetting.svdex_products_category_id, SiteSetting.svdex_presales_category_id]
            results.where.not(id: Category.where(id: ids).where.not(topic_id: nil).select(:topic_id))
          else
            results
          end
        end
      end
    end
  end
end
