# frozen_string_literal: true
abort "Local consolidation only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
require "digest"

actor = User.find_by!(username: "svdex")
discussion = Category.find_by!(slug: "discussion")
listings = Category.find(SiteSetting.svdex_listings_category_id)
staff = Category.find_by!(slug: "staff")
sources = Category.where(slug: %w[general feedback site-feedback]).to_a
raise "Discussion must remain public" if discussion.read_restricted?
raise "Staff must remain private" unless staff.read_restricted?
sources.each do |category|
  raise "Cannot consolidate a restricted category" if category.read_restricted?
  raise "Cannot consolidate a system uncategorized category" if category.uncategorized?
  raise "Move child categories explicitly first" if category.has_children?
end

description_ids = sources.map(&:topic_id)
topics = Topic.with_deleted.where(category_id: sources.map(&:id)).where.not(id: description_ids).to_a
post_fingerprints = Post.with_deleted.where(topic_id: topics.map(&:id)).pluck(:id, :raw, :user_id).to_h do |id, raw, user_id|
  [id, [Digest::SHA256.hexdigest(raw), user_id]]
end
channels = Chat::CategoryChannel.where(chatable_id: sources.map(&:id)).to_a
channel_fingerprints = channels.to_h do |channel|
  [channel.id, { messages: channel.chat_messages.pluck(:id), members: channel.user_chat_channel_memberships.pluck(:id) }]
end
snapshot = {
  categories: sources.map(&:attributes), topics: topics.map { |topic| { id: topic.id, category_id: topic.category_id } },
  channels: channels.map(&:attributes), settings: { general: SiteSetting.general_category_id, meta: SiteSetting.meta_category_id },
}
path = "/tmp/svdex-category-consolidation-before.json"
File.write(path, JSON.pretty_generate(snapshot), perm: 0o600) unless sources.empty? || File.exist?(path)

Category.transaction do
  # Both old and new categories are public. Keep the same channel, messages and
  # memberships, changing only its native category association.
  channels.each do |channel|
    changes = { chatable: discussion }
    changes[:featured_in_category_id] = discussion.id if sources.any? { |source| source.id == channel.featured_in_category_id }
    channel.update!(changes)
    Chat::Publisher.publish_chat_channel_edit(channel, actor)
  end

  topics.each do |topic|
    raise "Could not move topic #{topic.id}" unless topic.change_category_to_id(discussion.id, silent: true)
  end

  CategoryUser.where(category_id: sources.map(&:id)).find_each do |preference|
    existing = CategoryUser.find_by(user_id: preference.user_id, category_id: discussion.id)
    level = [existing&.notification_level || CategoryUser.notification_levels[:regular], preference.notification_level].max
    CategoryUser.set_notification_level_for_category(preference.user, level, discussion.id)
  end

  SiteSetting.default_composer_category = discussion.id
  SiteSetting.default_navigation_menu_categories = [listings.id, discussion.id].join("|")
  SiteSetting.general_category_id = discussion.id
  if SiteSetting.meta_category_id.to_i <= 0 || sources.any? { |source| source.id == SiteSetting.meta_category_id.to_i }
    SiteSetting.meta_category_id = discussion.id
  end

  sources.each do |source|
    source.reload
    raise "Regular topics remain in #{source.name}" if Topic.with_deleted.where(category_id: source.id).where.not(id: source.topic_id).exists?
    raise "Chat channel remains in #{source.name}" if Chat::CategoryChannel.exists?(chatable_id: source.id)
    CategoryDestroyer.destroy(actor.guardian, source)
  end

  post_fingerprints.each do |id, fingerprint|
    post = Post.with_deleted.find(id)
    raise "Post content/ownership changed" unless [Digest::SHA256.hexdigest(post.raw), post.user_id] == fingerprint
    raise "Topic was not moved" unless post.topic.category_id == discussion.id
  end
  channel_fingerprints.each do |id, fingerprint|
    channel = Chat::CategoryChannel.find(id)
    raise "Chat history or membership changed" unless channel.chat_messages.pluck(:id) == fingerprint[:messages] && channel.user_chat_channel_memberships.pluck(:id) == fingerprint[:members]
    raise "Chat association did not change" unless channel.chatable_id == discussion.id
  end
  raise "Staff visibility changed" unless staff.reload.read_restricted?
  raise "Listing approval changed" unless listings.reload.topic_posting_review_mode == "everyone"
end

puts JSON.pretty_generate(moved_topics: topics.map(&:id), moved_channels: channels.map(&:id),
  public_categories: Category.where(read_restricted: false).order(:id).pluck(:name), staff_private: staff.read_restricted?)
