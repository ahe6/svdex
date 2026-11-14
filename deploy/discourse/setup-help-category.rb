# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
actor = User.find_by!(username: "svdex")
help = Category.find_by(id: SiteSetting.svdex_help_category_id) || Category.find_by(slug: "feedback") || Category.find_by(slug: "help") || Category.find_by(slug: "help-feedback")
unless help
  help = Category.create!(name: "Feedback", slug: "feedback", color: "9863AD", text_color: "FFFFFF", user: actor)
  description = "Ask questions about SVDEX, report problems and share feedback or feature ideas."
  raise "Could not save Help description" unless PostRevisor.new(help.topic.first_post).revise!(actor, raw: description)
end
help.update!(name: "Feedback", slug: "feedback")
raise "Help must be public" if help.read_restricted?
SiteSetting.svdex_help_category_id = help.id
SiteSetting.meta_category_id = help.id
native_topics = [Topic.find_by(id: SiteSetting.guidelines_topic_id.to_i),
  Topic.find_by(slug: "welcome-to-svdex", user_id: Discourse.system_user.id)].compact.uniq
native_topics.each do |native_topic|
  native_post = native_topic.first_post
  next unless native_post
  old_link = %r{\[Site Feedback\]\((?:#{Regexp.escape(Discourse.base_url)})?/c/site-feedback/\d+\)}
  repaired = native_post.raw.gsub(old_link, "[#{help.name}](#{help.url})")
  repaired = repaired.gsub(/(?<![\w\/])#site-feedback(?![\w-])/, "##{help.slug}")
  next if repaired == native_post.raw
  raise "Could not repair native feedback link" unless PostRevisor.new(native_post).revise!(actor, { raw: repaired }, skip_validations: true, bypass_bump: true)
end
puts "Feedback: #{help.url}; public, with normal notification preferences"
