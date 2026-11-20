# frozen_string_literal: true

module DiscourseSvdex
  module SecuritiesDirectory
    CATALOG_KEY = "svdex_catalog_security_key"

    def self.available?(id)
      id.to_i.positive? && [SiteSetting.svdex_listings_category_id.to_i, SiteSetting.svdex_public_offerings_category_id.to_i].include?(id.to_i)
    end

    def self.public_category
      category = Category.find_by(id: SiteSetting.svdex_public_offerings_category_id, read_restricted: false)
      category if category && category.id != SiteSetting.svdex_private_offerings_category_id.to_i &&
        category.parent_category_id == SiteSetting.svdex_listings_category_id.to_i && Guardian.new.can_see?(category)
    end

    def self.eligible?(topic, category = public_category)
      category && topic && topic.category_id == category.id && topic.id != category.topic_id &&
        topic.archetype == Archetype.default && topic.visible? && !topic.deleted_at
    end
  end
end
