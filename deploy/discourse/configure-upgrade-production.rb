# frozen_string_literal: true
# Apply reviewed native configuration without importing any local fixture data.
abort "Explicit production upgrade required" unless GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_CONFIGURE_UPGRADE"] == "1"

actor = User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Expected active owner" unless actor&.admin? && actor.active?
parent = Category.find(SiteSetting.svdex_listings_category_id)
raise "Expected public Offerings" unless parent.slug == "offerings" && !parent.read_restricted?

ActiveRecord::Base.transaction do
  SiteSetting.general_category_id = Category.find_by!(slug: "discussion").id
  # Vocabulary is configuration. Local company tags and financial fixtures are not.
  topic_group = TagGroup.find_by_name_insensitive("Topics") || TagGroup.create!(name: "Topics")
  %w[community feedback financials founder-updates notifications research].each do |name|
    tag = Tag.find_by(name: name) || Tag.create!(name: name)
    topic_group.tags << tag unless topic_group.tags.exists?(tag.id)
  end
  welcome = Topic.find_by(slug: "welcome-to-svdex", user_id: Discourse.system_user.id)
  if welcome && !welcome.tags.exists?(name: "community")
    PostRevisor.new(welcome.first_post).revise!(actor, { tags: (welcome.tags.pluck(:name) + ["community"]).uniq }, skip_validations: true, bypass_bump: true)
  end

  feedback = Category.find(SiteSetting.svdex_help_category_id)
  raise "Unexpected support category" unless %w[help feedback].include?(feedback.slug) && !feedback.read_restricted?
  feedback.update!(name: "Feedback", slug: "feedback")
  SiteSetting.meta_category_id = feedback.id
  SiteSetting.contact_url = "https://svdex.com#{feedback.url}"

  section = SidebarSection.find_by!(section_type: :community, public: true)
  section.sidebar_urls.where(value: %w[/about /faq /guidelines /rules /conduct /g]).each do |url|
    section.sidebar_section_links.where(linkable: url).destroy_all
  end

  native_topics = [Topic.find_by(id: SiteSetting.guidelines_topic_id.to_i),
    Topic.find_by(slug: "welcome-to-svdex", user_id: Discourse.system_user.id)].compact.uniq
  native_topics.each do |native_topic|
    native_post = native_topic.first_post
    next unless native_post
    old_link = %r{\[Site Feedback\]\((?:#{Regexp.escape(Discourse.base_url)})?/c/site-feedback/\d+\)}
    repaired = native_post.raw.gsub(old_link, "[#{feedback.name}](#{feedback.url})")
    repaired = repaired.gsub(/(?<![\w\/])#site-feedback(?![\w-])/, "##{feedback.slug}")
    next if repaired == native_post.raw
    raise "Could not repair native feedback link" unless PostRevisor.new(native_post).revise!(actor, { raw: repaired }, skip_validations: true, bypass_bump: true)
  end

  group = Group.find_or_initialize_by(name: SiteSetting.svdex_private_offerings_group_name)
  if group.new_record?
    group.assign_attributes(full_name: "Private Deals members", visibility_level: Group.visibility_levels[:members],
      members_visibility_level: Group.visibility_levels[:members], public_admission: false,
      public_exit: false, allow_membership_requests: false)
    group.save!
  end
  raise "Private membership must stay invitation-only" if group.public_admission || group.allow_membership_requests
  category = Category.find_by(id: SiteSetting.svdex_private_offerings_category_id) || Category.find_by(slug: "private-offerings", parent_category_id: parent.id)
  unless category
    category = Category.new(name: "Private offerings", slug: "private-offerings", parent_category_id: parent.id,
      user: actor, color: parent.color, text_color: parent.text_color,
      topic_posting_review_mode: parent.topic_posting_review_mode,
      reply_posting_review_mode: parent.reply_posting_review_mode,
      minimum_required_tags: parent.minimum_required_tags)
    category.set_permissions(group.name => :full, "staff" => :full)
    category.save!
    category.reload.update!(topic_posting_review_mode: parent.topic_posting_review_mode, reply_posting_review_mode: parent.reply_posting_review_mode,
      description: "Access-restricted primary offerings and private secondary sale opportunities.")
  end
  raise "Expected restricted Offerings child" unless category.read_restricted? && category.parent_category_id == parent.id
  raise "Private category visible to guests" if Guardian.new.can_see_category?(category)
  SiteSetting.svdex_private_offerings_category_id = category.id
  SiteSetting.svdex_private_access_contact = actor.username
  SiteSetting.svdex_private_access_form_url = "https://tally.so/r/xVM7or"

  grouping = BadgeGrouping.find_by!(name: "SVDEX")
  Badge.find_by!(name: "Early Explorer").update!(icon: "compass")
  Badge.find_by!(name: "Verified Accredited Investor").update!(icon: "shield-halved")
  badge = Badge.find_or_initialize_by(name: "Private Access")
  if badge.new_record?
    badge.assign_attributes(badge_grouping: grouping, badge_type_id: BadgeType::Silver,
      description: "Invited to the private deals area.",
      long_description: "Granted when the SVDEX team adds a member to the private offerings group. Removed when that membership ends. Access is controlled by group membership, not this achievement.",
      icon: "key", enabled: true, listable: true, allow_title: false, multiple_grant: false,
      auto_revoke: false, target_posts: false, show_posts: false, trigger: Badge::Trigger::None)
    badge.save!
  end
  raise "Private Access must be manual" unless badge.query.blank? && badge.trigger == Badge::Trigger::None

  SiteSetting.nested_replies_enabled = true
  SiteSetting.nested_replies_default = true
  SiteSetting.discourse_events_enabled = true
  SiteSetting.discourse_post_event_enabled = true
  SiteSetting.discourse_post_event_allowed_on_groups = "1|2|10"
  SiteSetting.enable_improved_event_reminders = true
  SiteSetting.sidebar_show_upcoming_events = false
end
DiscourseTagging.clear_cache!
puts "Native upgrade configured: Feedback, secured private-access discovery, badge icons, member Events and reminder preferences. No members added, badges awarded or financial fixtures imported."
