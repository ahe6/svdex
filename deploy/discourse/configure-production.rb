# frozen_string_literal: true
# Fresh-site setup only: no local users, topics, company facts or fixture imports.
staging = GlobalSetting.hostname == "staging.svdex.com" && ENV["SVDEX_STAGING_SETUP"] == "1" && SiteSetting.disable_emails == "yes"
abort "Expected a closed, explicitly authorized installation" unless (GlobalSetting.hostname == "svdex.com" || staging) && SiteSetting.login_required && !SiteSetting.allow_new_registrations
abort "Explicit setup flag required" unless ENV["SVDEX_INITIAL_SETUP"] == "1"
actor = User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Production administrator required" unless actor&.admin? && actor.active?
root = "/shared/svdex-release"
SiteSetting.title = "SVDEX"
SiteSetting.site_description = "Company research, discussion and private-capital opportunities."
SiteSetting.contact_email = ""
SiteSetting.reply_by_email_enabled = false
SiteSetting.wizard_enabled = false
SiteSetting.enable_site_owner_onboarding = false
SiteSetting.tagging_enabled = true
SiteSetting.tags_listed_by_group = true
SiteSetting.chat_enabled = true
require_relative "native-defaults"
SvdexNativeDefaults.apply!(:navigation)
SvdexNativeDefaults.apply!(:events)
SiteSetting.discourse_post_event_allowed_on_groups = "1|2|10"
SiteSetting.enable_public_channels = true
SiteSetting.top_menu = "latest|top"
SiteSetting.desktop_category_page_style = "categories_only"
SiteSetting.mobile_category_page_style = "categories_only"
SiteSetting.backup_frequency = 1
SiteSetting.backup_with_uploads = true
SiteSetting.maximum_backups = 7
SiteSetting.backup_location = "local"

categories = {}
{
  "offerings" => ["Offerings", "0088CC", "Explore financing rounds and securities offered by companies. Review disclosed terms and discuss each opportunity."],
  "discussion" => ["Discussion", "2396BF", "Share company research, market insights and community conversation. Discuss companies, investing and private markets."],
  "feedback" => ["Feedback", "9863AD", "Ask questions about SVDEX, report problems and share feedback or feature ideas."],
}.each do |slug, (name, color, description)|
  category = Category.find_by(slug: slug) || Category.create!(name: name, slug: slug, color: color, text_color: "FFFFFF", user: actor)
  raise "Public category unexpectedly restricted" if category.read_restricted?
  post = category.topic.first_post
  raise "Could not set category description" unless post.raw == description || PostRevisor.new(post).revise!(actor, raw: description)
  categories[slug] = category
end
SiteSetting.svdex_listings_category_id = categories.fetch("offerings").id
SiteSetting.svdex_help_category_id = categories.fetch("feedback").id
SiteSetting.meta_category_id = categories.fetch("feedback").id
SiteSetting.contact_url = "#{Discourse.base_url}#{categories.fetch("feedback").url}"
feedback_category = categories.fetch("feedback")
native_topics = [Topic.find_by(id: SiteSetting.guidelines_topic_id.to_i),
  Topic.find_by(slug: "welcome-to-svdex", user_id: Discourse.system_user.id)].compact.uniq
native_topics.each do |native_topic|
  native_post = native_topic.first_post
  next unless native_post
  old_link = %r{\[Site Feedback\]\((?:#{Regexp.escape(Discourse.base_url)})?/c/site-feedback/\d+\)}
  repaired = native_post.raw.gsub(old_link, "[#{feedback_category.name}](#{feedback_category.url})")
  repaired = repaired.gsub(/(?<![\w\/])#site-feedback(?![\w-])/, "##{feedback_category.slug}")
  next if repaired == native_post.raw
  raise "Could not repair native feedback link" unless PostRevisor.new(native_post).revise!(actor, { raw: repaired }, skip_validations: true, bypass_bump: true)
end
SiteSetting.default_composer_category = categories.fetch("discussion").id
SiteSetting.general_category_id = categories.fetch("discussion").id
SiteSetting.default_navigation_menu_categories = categories.values.map(&:id).join("|")
categories.fetch("offerings").update!(topic_posting_review_mode: "everyone", reply_posting_review_mode: "no_one")

# Native starter content is retained in Discussion or Feedback; its empty category stays
# private rather than deleting content during provisioning.
{ "general" => "discussion", "site-feedback" => "feedback" }.each do |slug, destination|
  starter = Category.find_by(slug: slug)
  next unless starter && starter.id != categories.fetch(destination).id
  starter.topics.where.not(id: starter.topic_id).find_each do |topic|
    raise "Could not move starter topic" unless topic.change_category_to_id(categories.fetch(destination).id, silent: true)
  end
  starter.set_permissions("staff" => :full)
  starter.save!
end
SiteSetting.allow_uncategorized_topics = false
%w[companies funds].each do |name|
  group = Group.find_by(name: name) || Group.create!(name: name, full_name: name.capitalize, visibility_level: Group.visibility_levels[:public], members_visibility_level: Group.visibility_levels[:public])
  group.update!(public_admission: false, public_exit: false, allow_membership_requests: false)
end
%w[Companies Sectors Topics].each { |name| TagGroup.find_by_name_insensitive(name) || TagGroup.create!(name: name) }
topic_group = TagGroup.find_by_name_insensitive("Topics")
%w[community feedback financials founder-updates notifications research].each do |name|
  tag = Tag.find_by(name: name) || Tag.create!(name: name)
  topic_group.tags << tag unless topic_group.tags.exists?(tag.id)
end
welcome = Topic.find_by(slug: "welcome-to-svdex", user_id: Discourse.system_user.id)
if welcome && !welcome.tags.exists?(name: "community")
  PostRevisor.new(welcome.first_post).revise!(actor, { tags: (welcome.tags.pluck(:name) + ["community"]).uniq }, skip_validations: true, bypass_bump: true)
end
sector_group = TagGroup.find_by_name_insensitive("Sectors")
sectors = {
  "software" => "Software products, platforms and developer tools.",
  "ai" => "Artificial intelligence models, applications and infrastructure.",
  "hardware" => "Physical computing, electronics, instruments and devices.",
  "finance" => "Financial services, investing and financial technology.",
  "healthcare" => "Healthcare delivery, services and medical technology.",
  "biotech" => "Biological research, therapeutics and life-science tools.",
  "energy" => "Energy generation, storage, infrastructure and services.",
  "climate" => "Climate mitigation, adaptation and environmental technology.",
  "industrials" => "Manufacturing, industrial equipment and automation.",
  "consumer" => "Consumer products, brands and retail businesses.",
  "property" => "Real estate, property services and property technology.",
  "transport" => "Mobility, logistics and transportation businesses.",
  "education" => "Learning products, education services and training.",
  "media" => "Media, entertainment, content and communications.",
  "agriculture" => "Farming, food production and agricultural technology.",
}
sectors.each do |name, description|
  tag = Tag.find_or_initialize_by(name: name)
  tag.description = description if tag.description.blank?
  tag.save!
  sector_group.tags << tag unless sector_group.tags.exists?(tag.id)
end
DiscourseTagging.clear_cache!

component = RemoteTheme.import_theme_from_directory("#{root}/sidebar", theme_id: Theme.find_by(name: "SVDEX Sidebar", component: true)&.id)
raise component.errors.full_messages.join(", ") unless component.persisted? && component.errors.empty?
interface = RemoteTheme.import_theme_from_directory("#{root}/interface", theme_id: Theme.find_by(name: "SVDEX Interface", component: true)&.id)
raise interface.errors.full_messages.join(", ") unless interface.persisted? && interface.errors.empty?
raise "Interface JavaScript compilation failed" if interface.javascript_cache&.content.to_s.start_with?("throw new Error(")
schemes = {}
{ "light" => "Light", "dark" => "Dark" }.each do |mode, name|
  schemes[mode] = ColorScheme.find_by(name: "Discourse #{name}") || ColorScheme.create_from_base(name: "Discourse #{name}", base_scheme_id: ColorScheme::NAMES_TO_ID_MAP.fetch(name), colors: {})
  raise "Could not install native palette" unless schemes[mode].persisted?
end
theme = Theme.find_by(name: "SVDEX", component: false) || Theme.create!(name: "SVDEX", user_id: actor.id)
theme.assign_attributes(color_scheme_id: schemes.fetch("light").id, dark_color_scheme_id: schemes.fetch("dark").id, user_selectable: true, enabled: true)
theme.child_theme_ids = [component.id, interface.id]
theme.set_field(target: :common, name: "scss", value: File.read("#{root}/appearance/common.scss"))
theme.save!
result = Themes::ThemeSiteSettingManager.call(guardian: actor.guardian, params: { theme_id: theme.id, name: "enable_welcome_banner", value: false })
raise "Could not set theme welcome banner" unless result.success?
require "tempfile"
wordmark = File.read("#{root}/brand/svdex-wordmark.svg")
{ light: wordmark.sub('fill="#f2f4fb"', 'fill="#282b2e"'), dark: wordmark }.each do |mode, data|
  upload = Upload.find_by(sha1: Digest::SHA1.hexdigest(data)) || Tempfile.create(["svdex-wordmark-#{mode}", ".svg"]) do |file|
    file.write(data); file.flush
    UploadCreator.new(file, "svdex-wordmark-#{mode}.svg", for_site_setting: true).create_for(actor.id)
  end
  raise "Could not install wordmark" unless upload.persisted?
  if mode == :light
    SiteSetting.logo = upload.id
    SiteSetting.mobile_logo = upload.id
  else
    SiteSetting.logo_dark = upload.id
    SiteSetting.mobile_logo_dark = upload.id
  end
end
SiteSetting.default_theme_id = theme.id
Theme.find(Theme::CORE_THEMES.fetch("foundation")).update!(user_selectable: false)
SiteSetting.enable_powered_by_discourse = false
SiteSetting.interface_color_selector = "sidebar_footer"
TranslationOverride.upsert!("en", "js.sidebar.footer.interface_color_selector.auto", "System")
TranslationOverride.upsert!("en", "js.badges.title", "Achievements")
section = SidebarSection.find_by!(section_type: :community, public: true)
  # The theme API now owns primary directory/feed links and active states.

%w[/about /faq /guidelines /rules /conduct /badges /tags /u /g /my/activity /my/messages /review /admin /new-invite].each do |value|
  url = section.sidebar_urls.find_by(value: value)
  section.sidebar_section_links.where(linkable: url).destroy_all if url
end
section.sidebar_urls.where(value: ["/companies", "/latest"]).each do |entry|
  section.sidebar_section_links.where(linkable: entry).destroy_all
end

badge_group = BadgeGrouping.find_by(name: "SVDEX") || BadgeGrouping.create!(name: "SVDEX", description: "SVDEX contributions and verification", position: 0)
[
  ["Early Explorer", BadgeType::Bronze, "Helped shape SVDEX in its early days.", "Awarded by the team for exploring SVDEX and sharing thoughtful feedback during its early days."],
  ["Verified Accredited Investor", BadgeType::Silver, "Accredited-investor verification reviewed by SVDEX.", "Awarded manually by the SVDEX team after reviewing accredited-investor verification."],
].each do |name, type, description, long_description|
  next if Badge.exists?(name: name)
  Badge.create!(name: name, badge_grouping: badge_group, badge_type_id: type, description: description, long_description: long_description, icon: "certificate", enabled: true, listable: true, allow_title: false, multiple_grant: false, auto_revoke: false, target_posts: false, show_posts: false, trigger: Badge::Trigger::None)
end
unless Chat::CategoryChannel.exists?(chatable: categories.fetch("discussion"), name: "Lounge")
  result = Chat::CreateCategoryChannel.call(guardian: actor.guardian, params: { category_id: categories.fetch("discussion").id, name: "Lounge", slug: "lounge", description: "Casual conversation, introductions and quick questions with the SVDEX community.", auto_join_users: true })
  raise "Could not create public channel" unless result.success?
end
PluginStore.set("svdex", "production_setup_source", JSON.parse(File.read("#{root}/manifest.json")).fetch("source_commit"))
puts "Production structure configured; no company accounts, financial facts or offering fixtures imported. Access remains closed."

require_relative "configure-people"

require_relative "configure-presales"

require_relative "configure-discoveries"
