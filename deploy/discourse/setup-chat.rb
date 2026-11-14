# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

SiteSetting.chat_enabled = true
SiteSetting.enable_public_channels = true
actor = User.find_by!(username: "svdex")
category = Category.find_by!(slug: "discussion")
raise "Lounge must use the public Discussion category" if category.read_restricted?
channel = Chat::CategoryChannel.find_by(chatable: category, name: "Lounge") ||
  Chat::CategoryChannel.find_by(chatable: category, name: "General")
params = {
  name: "Lounge", slug: "lounge",
  description: "Casual conversation, introductions and quick questions with the SVDEX community.",
  auto_join_users: true,
}
result = if channel
  Chat::UpdateChannel.call(guardian: actor.guardian, params: params.merge(channel_id: channel.id))
else
  Chat::CreateCategoryChannel.call(guardian: actor.guardian, params: params.merge(category_id: category.id))
end
raise "Could not configure Lounge: #{result.inspect}" unless result.success?
channel = Chat::CategoryChannel.find_by!(chatable: category, name: "Lounge")
raise "Lounge is not open" unless channel.open?
puts "Lounge: #{channel.relative_url}; native Discussion-category permissions; auto-join enabled"
