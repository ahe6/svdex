# frozen_string_literal: true
# Owner-approved live content. Never load local offering fixtures here.
abort "Explicit production publication required" unless GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_PUBLISH_COMPANY_PROFILE"] == "1"
owner_email = ENV.fetch("SVDEX_COMPANY_OWNER_EMAIL")
raise "Expected approved owner address" unless owner_email == "austin@svdex.com"
actor = User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Expected active owner" unless actor&.admin? && actor.active?
username = "svdex"
company_tag_name = "svdex"
category = Category.find(SiteSetting.svdex_listings_category_id)
raise "Offering review must remain enabled" unless category.slug == "offerings" && category.topic_posting_review_mode == "everyone"
source_key = "svdex-safe-live"

User.transaction do
  user = User.find_by(username_lower: username.downcase)
  email_owner = User.find_by_email(owner_email)
  raise "Address belongs to a different account" if email_owner && email_owner != user
  raise "Username belongs to a different owner" if user && user.email.downcase != owner_email.downcase
  unless user
    # Passwordless native account: the owner can request an email login code.
    # Do not fabricate an email verification or request a password reset here.
    user = User.create!(username: username, name: "SVDEX", email: owner_email,
      active: true, approved: true, approved_by: actor, approved_at: Time.current,
      trust_level: 0, send_welcome_message: false)
    StaffActionLogger.new(actor).log_custom("svdex_company_profile_created", user_id: user.id)
  end
  raise "Company account must remain ordinary" if user.admin? || user.moderator? || user.staged?
  group = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
  raise "Company classification must remain staff-managed" if group.public_admission || group.allow_membership_requests
  group.add(user) unless group.users.exists?(id: user.id)
  company_tags = TagGroup.find_by_name_insensitive("Companies")
  tag = Tag.find_by(name: company_tag_name) || Tag.create!(name: company_tag_name)
  company_tags.tags << tag unless company_tags.tags.exists?(tag.id)
  sector = TagGroup.find_by_name_insensitive("Sectors").tags.find_by!(name: "finance")
  user.custom_fields["svdex_company_entity_type"] ||= "company"
  user.custom_fields["svdex_company_tag_id"] ||= tag.id.to_s
  user.custom_fields["svdex_company_sector_tag_id"] ||= sector.id.to_s
  user.save_custom_fields
  profile = user.user_profile
  profile.update!(bio_raw: "Company research, discussion and private-capital opportunities.") if profile.bio_raw.blank?
  profile.update!(website: "https://svdex.com") if profile.website.blank?

  topic = TopicCustomField.find_by(name: "svdex_live_source_id", value: source_key)&.topic
  unless topic
    result = NewPostManager.new(user,
      title: "SVDEX — SAFE offering", category: category.id, tags: [tag.name, sector.name],
      raw: "A proposed SAFE for SVDEX. Financial terms have not been specified yet. Details will be added as they are decided.\n\nUse this topic for questions and discussion about the proposed SAFE.",
      svdex_summary: "Proposed SAFE financing for SVDEX. Financial terms are not yet specified.",
    ).perform
    raise "Offering was not queued: #{result.errors.full_messages}" unless result.success? && result.action == :enqueued
    approved = result.reviewable.perform(actor, :approve_post)
    raise "Native offering approval failed" unless approved.success?
    topic = approved.created_post.topic.reload
    topic.custom_fields["svdex_live_source_id"] = source_key
    topic.save_custom_fields
  end
  raise "Wrong offering owner/category" unless topic.first_post.user_id == user.id && topic.category_id == category.id && topic.visible?
  raise "Unexpected offering financial values" unless (DiscourseSvdex::FIELDS.keys - ["svdex_summary"]).all? { |key| topic.custom_fields[key].blank? }
  raise "Unexpected company financial figures" unless %w[svdex_company_total_funding_usd svdex_company_last_valuation_usd svdex_company_fund_size_usd].all? { |key| user.custom_fields[key].blank? }
  raise "Private access must not be granted" if user.groups.exists?(name: SiteSetting.svdex_private_offerings_group_name)
  StaffActionLogger.new(actor).log_custom("svdex_safe_publication_checked", user_id: user.id, topic_id: topic.id)
  puts JSON.generate(company_profile: "/u/#{user.username}", offering: topic.relative_url, owner_email: user.email, financial_terms: "unspecified", native_review: "approved")
end
DirectoryItem.refresh_period!(:all)
