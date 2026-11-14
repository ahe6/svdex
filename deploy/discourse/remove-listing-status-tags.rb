# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
key = "removed_listing_status_tags_v1"
unless PluginStore.get("discourse-svdex", key)
  actor = User.find_by!(username: "svdex")
  Tag.transaction do
    tags = Tag.where(name: %w[listed interest interest-only]).to_a
    snapshot = tags.map { |tag| { name: tag.name, description: tag.description, topic_ids: tag.topics.pluck(:id), groups: tag.tag_groups.pluck(:name) } }
    PluginStore.set("discourse-svdex", key, snapshot)
    tags.each do |tag|
      name = tag.name
      tag.destroy!
      StaffActionLogger.new(actor).log_custom("deleted_tag", subject: name)
    end
    TagGroup.find_by_name_insensitive("Listing status")&.destroy!
    puts "Removed status tags: #{snapshot.map { |tag| tag[:name] }.join(', ')}"
  end
end
DiscourseTagging.clear_cache!
