# frozen_string_literal: true
module DiscourseSvdex
  class PrivateAccessController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    def index
      render "default/empty"
    end

    # Public discovery may advertise the access process, not restricted topic
    # counts/activity. Only viewers with native category access receive totals.
    def summary
      category_id = SiteSetting.svdex_private_offerings_category_id
      category = Category.find_by(id: category_id)
      return render json: {} unless category && guardian.can_see?(category)
      topics = Topic.where(category_id: category_id, archetype: Archetype.default, visible: true)
        .where.not(id: Category.where(id: category_id).select(:topic_id))
      render json: { topic_count: topics.count, topics_week: topics.where("topics.created_at >= ?", 1.week.ago).count }
    end
  end
end
