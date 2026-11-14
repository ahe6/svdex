# frozen_string_literal: true
abort "Explicit approved production cleanup required" unless GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_RETIRE_DEFAULT_CATEGORIES"] == "1" && ENV["SVDEX_OFFSITE_BACKUP_CONFIRMED"] == "1"
actor = User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Expected active owner" unless actor&.admin? && actor.active?
sources = Category.where(slug: %w[general site-feedback]).to_a
staff = Category.find_by!(slug: "staff")
raise "Staff must stay private" unless staff.read_restricted?
channels = Chat::CategoryChannel.where(chatable_type: "Category", chatable_id: sources.map(&:id)).to_a
channel_state = channels.to_h do |channel|
  raise "Expected staff-only chat permissions" unless channel.read_restricted? && channel.allowed_group_ids.sort == Chat::CategoryChannel::STAFF_GROUP_IDS.sort
  [channel.id, { messages: channel.chat_messages.with_deleted.pluck(:id).sort, members: channel.user_chat_channel_memberships.pluck(:id).sort, permissions: channel.allowed_group_ids.sort }]
end
sources.each do |category|
  raise "Unexpected default category" unless ["General", "Site Feedback"].include?(category.name)
  raise "Expected staff-only retired default" unless category.read_restricted? && category.category_groups.joins(:group).pluck("groups.name").sort == ["staff"]
  raise "Default contains ordinary or deleted topics" if Topic.with_deleted.where(category_id: category.id).where.not(id: category.topic_id).exists?
  raise "Default contains children" if category.has_children?
  raise "Default is still used by core" if category.seeded?
end
unless sources.empty?
  path = "/shared/svdex-auth/retired-default-categories-before.json"
  File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) do |file|
    file.write(JSON.pretty_generate(categories: sources.map { |c| { category: c.attributes, topics: Topic.with_deleted.where(category_id: c.id).map(&:attributes), posts: Post.with_deleted.where(topic_id: c.topic_id).map(&:attributes) } }, channels: channels.map(&:attributes), channel_state: channel_state))
  end unless File.exist?(path)
end
Category.transaction do
  # Retain the channel and all memberships/messages under the same staff-only
  # access. Closing it removes the unused default from the open chat directory.
  channels.each do |channel|
    channel.update!(chatable: staff, featured_in_category_id: nil, auto_join_users: false)
    channel.closed!(actor) unless channel.closed?
    raise "Could not close retained default chat" unless channel.closed?
    before = channel_state.fetch(channel.id)
    raise "Chat content changed" unless channel.chat_messages.with_deleted.pluck(:id).sort == before[:messages]
    raise "Chat membership changed" unless channel.user_chat_channel_memberships.pluck(:id).sort == before[:members]
    raise "Chat privacy changed" unless channel.allowed_group_ids.sort == before[:permissions]
    Chat::Publisher.publish_chat_channel_edit(channel, actor)
  end
  sources.each { |category| CategoryDestroyer.destroy(actor.guardian, category) }
  raise "Public Feedback disappeared" unless Category.find_by!(slug: "feedback").id == SiteSetting.svdex_help_category_id.to_i
  raise "Discussion default changed" unless Category.find_by!(slug: "discussion").id == SiteSetting.general_category_id.to_i
  raise "Private offering access changed" unless Category.find(SiteSetting.svdex_private_offerings_category_id).read_restricted?
end
puts "Removed only the approved empty defaults: #{sources.map(&:name).join(', ')}"
