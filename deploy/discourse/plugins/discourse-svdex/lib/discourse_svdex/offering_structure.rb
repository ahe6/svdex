# frozen_string_literal: true
module DiscourseSvdex
  module OfferingStructure
    VISIBILITY_TAGS = %w[public-offering private-offering].freeze
    EXEMPTION_TAGS = %w[506b 506c 4a7].freeze

    # Visibility follows native category placement. It never grants access or
    # infers a securities exemption. Use native TopicTag callbacks for counters.
    def self.sync_visibility!(topic)
      return unless topic&.persisted? && topic.archetype == Archetype.default
      return if Category.exists?(topic_id: topic.id)
      name = if topic.category_id == SiteSetting.svdex_public_offerings_category_id.to_i
        "public-offering"
      elsif topic.category_id == SiteSetting.svdex_private_offerings_category_id.to_i
        "private-offering"
      end
      ids = Tag.where(name: VISIBILITY_TAGS).pluck(:id)
      desired = name && Tag.find_by(name: name)
      return if name && !desired # Configuration may not have run yet.
      stale = topic.topic_tags.where(tag_id: ids - [desired&.id])
      changed = stale.exists?
      stale.destroy_all
      if desired && !topic.topic_tags.exists?(tag_id: desired.id)
        topic.topic_tags.create!(tag: desired)
        changed = true
      end
      if changed
        topic.tags.reset
        TagUser.auto_watch(topic_id: topic.id)
        TagUser.auto_track(topic_id: topic.id)
        SearchIndexer.queue_post_reindex(topic.id)
      end
    end

    def self.configure!(actor)
      raise "Administrator required" unless actor&.admin?
      parent = Category.find(SiteSetting.svdex_listings_category_id)
      private_category = Category.find(SiteSetting.svdex_private_offerings_category_id)
      raise "Expected public Offerings parent" unless parent.slug == "offerings" && !parent.read_restricted?
      raise "Expected secured child" unless private_category.parent_category_id == parent.id && private_category.read_restricted?
      ActiveRecord::Base.transaction do
        public_category = Category.find_by(id: SiteSetting.svdex_public_offerings_category_id) || Category.find_by(slug: "public-offerings", parent_category_id: parent.id) || Category.new(user: actor)
        raise "Unexpected public category" if public_category.persisted? && (public_category.parent_category_id != parent.id || public_category.slug != "public-offerings" || public_category.read_restricted?)
        public_category.assign_attributes(name: "Public offerings", slug: "public-offerings", parent_category_id: parent.id,
          color: parent.color, text_color: parent.text_color, position: 0,
          topic_posting_review_mode: parent.topic_posting_review_mode,
          reply_posting_review_mode: parent.reply_posting_review_mode,
          minimum_required_tags: parent.minimum_required_tags, allow_global_tags: true)
        public_category.set_permissions("everyone" => :full, "staff" => :full) if public_category.new_record?
        public_category.save!
        public_category.update!(topic_posting_review_mode: parent.topic_posting_review_mode,
          description: "Publicly visible financing and secondary sale opportunities.")
        private_category.update!(name: "Private offerings", position: 1, allow_global_tags: true,
          description: "Access-restricted financing and private secondary sale opportunities.")
        SiteSetting.svdex_public_offerings_category_id = public_category.id

        {
          "Offering visibility" => VISIBILITY_TAGS,
          "Offering exemptions" => EXEMPTION_TAGS,
        }.each do |name, names|
          group = TagGroup.find_by_name_insensitive(name) || TagGroup.new(name: name)
          group.assign_attributes(one_per_topic: true, permissions: { "everyone" => :readonly, "staff" => :full })
          group.save!
          names.each do |tag_name|
            tag = Tag.find_by(name: tag_name) || Tag.create!(name: tag_name)
            group.tags << tag unless group.tags.exists?(tag.id)
          end
          group.category_ids = [public_category.id, private_category.id]
        end

        # Keep the parent as the combined destination, with no ordinary topics.
        Topic.where(category_id: parent.id).where.not(id: Category.where.not(topic_id: nil).select(:topic_id)).find_each do |topic|
          raise "Could not move public offering #{topic.id}" unless topic.change_category_to_id(public_category.id, silent: true)
        end
        ReviewableQueuedPost.pending.where(category_id: parent.id).find_each do |request|
          request.update!(category_id: public_category.id)
        end
        parent.set_permissions("everyone" => :readonly, "staff" => :full)
        parent.save!
        parent.update!(description: "Public and access-restricted financing and secondary sale opportunities.")
        SiteSetting.default_subcategory_on_read_only_category = true
        Topic.where(category_id: [public_category.id, private_category.id]).find_each { |topic| sync_visibility!(topic) }
      end
      DiscourseTagging.clear_cache!
    end
  end
end
