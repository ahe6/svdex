# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

require_relative "native-defaults"
SvdexNativeDefaults.apply!(:events)
SiteSetting.discourse_post_event_allowed_on_groups = "1|2|10"
# The theme places the same native sidebar link below Chat, labeled Events.
# Suppress core's additional Upcoming events entry to avoid duplicate links.

actor = User.find_by!(username: "svdex")
category = Category.find(SiteSetting.svdex_events_category_id)
source_key = "svdex-community-qa"
existing = TopicCustomField.find_by(name: "svdex_event_source", value: source_key)&.topic
starts_at = 7.days.from_now.in_time_zone("Asia/Shanghai").change(hour: 17, min: 0, sec: 0)
ends_at = starts_at + 30.minutes
raw = <<~MD
  Meet the SVDEX team, share feedback and discuss company research and upcoming features.

  [event start="#{starts_at.strftime('%Y-%m-%d %H:%M')}" end="#{ends_at.strftime('%Y-%m-%d %H:%M')}" timezone="Asia/Shanghai" status="public" name="SVDEX Community Q&A"]
  [/event]

  Bring your questions about using SVDEX, following companies and sharing research. Add questions below so we can cover them together.
MD
if existing
  PostRevisor.new(existing.first_post).revise!(actor, { category_id: category.id }, skip_validations: true) if existing.category_id != category.id
  PostRevisor.new(existing.first_post).revise!(actor, { raw: raw }, skip_validations: true)
  topic = existing
else
  post = PostCreator.create!(actor, title: "SVDEX Community Q&A", raw: raw,
    category: category.id, tags: ["community"], skip_validations: true, skip_jobs: true)
  topic = post.topic
  topic.custom_fields["svdex_event_source"] = source_key
  topic.save_custom_fields
end
raise "Native event was not created" unless topic.first_post.reload.event
puts "Native Events enabled; member creation enabled. #{topic.relative_url}"
