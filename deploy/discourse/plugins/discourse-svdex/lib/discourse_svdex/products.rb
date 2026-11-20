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
        topic.id != topic.category&.topic_id
    end

    def self.votes_for(topics, guardian)
      return {} if topics.empty?
      ActiveRecord::Associations::Preloader.new(records: topics, associations: { first_post: :user }).call
      posts = topics.filter_map do |topic|
        post = topic.first_post
        next unless post && !post.hidden?
        post.topic = topic
        post if guardian.can_see_post?(post)
      end
      likes = if guardian.authenticated?
        PostAction.active.where(user_id: guardian.user.id, post_id: posts.map(&:id), post_action_type_id: PostActionType.types[:like])
          .index_by(&:post_id)
      else
        {}
      end
      posts.to_h do |post|
        like = likes[post.id]
        can_toggle = if like
          like.post = post
          guardian.can_delete_post_action?(like)
        elsif guardian.authenticated?
          guardian.post_can_act?(post, :like, can_see_post: true)
        else
          !post.topic.archived?
        end
        [post.topic_id, { post_id: post.id, count: post.like_count, voted: like.present?, can_toggle: can_toggle }]
      end
    end

    module TopicListVotes
      def load_topics
        super.tap do |topics|
          products = topics.select { |topic| Products.topic?(topic) }
          votes = Products.votes_for(products, Guardian.new(current_user))
          products.each do |topic|
            topic.svdex_product_vote = votes.fetch(topic.id, false)
            topic.svdex_product_vote_viewer = current_user&.id
          end
        end
      end
    end

    def self.install!(plugin)
      Topic.attr_accessor :svdex_product_vote, :svdex_product_vote_viewer
      TopicList.prepend(TopicListVotes)
      plugin.instance_eval do
        add_to_serializer(:topic_list_item, :svdex_product, include_condition: -> { Products.topic?(object) }) do
          text = ActionView::Base.full_sanitizer.sanitize(object.excerpt.to_s)
          vote = object.svdex_product_vote if object.svdex_product_vote_viewer == scope.user&.id
          vote = Products.votes_for([object], scope)[object.id] if vote.nil?
          { summary: CGI.unescapeHTML(text).lines.first.to_s.squish.truncate(180), vote: vote || nil }
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
