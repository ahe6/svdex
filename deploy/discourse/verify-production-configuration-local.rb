# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

source = File.read("/tmp/configure-upgrade-production.rb")
guard = 'GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_CONFIGURE_UPGRADE"] == "1"'
raise "Production guard changed; review test adaptation" unless source.include?(guard)
source = source.sub(guard, 'GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"')
source = source.sub('User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)', 'User.find_by!(username: "svdex")')

ActiveRecord::Base.transaction do
  welcome = Topic.find_by!(slug: "welcome-to-svdex", user_id: Discourse.system_user.id)
  before = [User.count, Topic.with_deleted.count, Post.with_deleted.count, UserBadge.count]
  qa_old_welcome_raw = welcome.first_post.raw
  raw = qa_old_welcome_raw + "\n\n[Site Feedback](/c/site-feedback/2) and #site-feedback"
  welcome.first_post.update!(raw: raw)
  bumped_at = welcome.bumped_at
  TagGroup.find_by_name_insensitive("Topics")&.destroy!
  welcome.tags.delete(Tag.find_by!(name: "community"))
  SiteSetting.general_category_id = Category.find_by!(slug: "staff").id
  qa_guidelines_post = Topic.find(SiteSetting.guidelines_topic_id.to_i).first_post
  qa_input = qa_guidelines_post.raw + "\n\n[Site Feedback](/c/site-feedback/2)\n\n[Site Feedback](https://meta.discourse.org/c/site-feedback/4)\n\n#site-feedback\n\nhttps://meta.discourse.org/#site-feedback"
  qa_guidelines_post.update!(raw: qa_input)
  qa_feedback = Category.find(SiteSetting.svdex_help_category_id)
  qa_pattern = %r{\[Site Feedback\]\((?:#{Regexp.escape(Discourse.base_url)})?/c/site-feedback/\d+\)}
  qa_expected = qa_input.gsub(qa_pattern, "[#{qa_feedback.name}](#{qa_feedback.url})").gsub(/(?<![\w\/])#site-feedback(?![\w-])/, "##{qa_feedback.slug}")
  qa_expected_welcome = raw.gsub(qa_pattern, "[#{qa_feedback.name}](#{qa_feedback.url})").gsub(/(?<![\w\/])#site-feedback(?![\w-])/, "##{qa_feedback.slug}")
  qa_guidelines_bump = qa_guidelines_post.topic.bumped_at

  eval(source, binding, "configure-upgrade-production.rb")
  vocabulary = TagGroup.find_by_name_insensitive("Topics")
  raise "Missing Topics vocabulary" unless vocabulary.tags.pluck(:name).sort == %w[community feedback financials founder-updates notifications research]
  raise "Wrong general category" unless SiteSetting.general_category_id.to_i == Category.find_by!(slug: "discussion").id
  raise "Welcome tag missing" unless welcome.reload.tags.exists?(name: "community")
  raise "Welcome body changed" unless welcome.first_post.reload.raw == qa_expected_welcome
  raise "Welcome topic was bumped" unless welcome.bumped_at == bumped_at
  raise "Unexpected content, accounts or badge grants" unless before == [User.count, Topic.with_deleted.count, Post.with_deleted.count, UserBadge.count]
  puts "PASS missing production vocabulary and native defaults are repaired without new content or grants"
  puts "PASS welcome tagging and feedback link repair preserve other content and activity date"
  raise "Guidelines changed beyond the obsolete own-site link" unless qa_guidelines_post.reload.raw == qa_expected
  raise "Guidelines were bumped" unless qa_guidelines_post.topic.reload.bumped_at == qa_guidelines_bump
  raise "Obsolete native category mention still rendered" if [qa_guidelines_post, welcome.first_post].any? { |p| p.reload.cooked.include?('href="/c/site-feedback/2"') }
  puts "PASS Guidelines feedback link is repaired without changing external links, other policy text or activity date"

  ids = vocabulary.tags.pluck(:id).sort
  eval(source, binding, "configure-upgrade-production.rb")
  raise "Repeated migration duplicates tags" unless vocabulary.reload.tags.pluck(:id).sort == ids
  raise "Repeated migration changes content counts" unless before == [User.count, Topic.with_deleted.count, Post.with_deleted.count, UserBadge.count]
  puts "PASS native configuration migration is idempotent"
  raise ActiveRecord::Rollback
end
