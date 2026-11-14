# Run through Rails in the loopback-only Discourse container.
abort "This initializer is only for localhost:4080" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
if PluginStore.get("miscdex", "initial_setup_completed")
  puts "Local setup is already complete; existing admin settings were preserved."
  exit 0
end
password = STDIN.read.strip
abort "A generated admin password is required" if password.length < 24

admin = User.find_by_email("admin@miscdex.com")
if admin
  abort "Existing admin credentials differ; no password was changed" unless admin.confirm_password?(password)
else
  admin = User.create!(
    username: "svdex", name: "SVDEX", email: "admin@miscdex.com",
    password: password, active: true, approved: true,
  )
  admin.grant_admin!
  admin.change_trust_level!(1)
  admin.email_tokens.update_all(confirmed: true)
  admin.activate
end

foundation = Theme.find(Theme::CORE_THEMES.fetch("foundation"))
SiteSetting.default_theme_id = foundation.id
result = Themes::ThemeSiteSettingManager.call(
  guardian: admin.guardian,
  params: { theme_id: foundation.id, name: "enable_welcome_banner", value: false },
)
raise "Could not configure the theme's welcome banner" unless result.success?
SiteSetting.wizard_enabled = false
SiteSetting.enable_site_owner_onboarding = false
SiteSetting.tagging_enabled = true
SiteSetting.allow_uncategorized_topics = false
SiteSetting.chat_enabled = true
SiteSetting.top_menu = "latest|top|categories"
require "tempfile"
logo = Tempfile.create(["svdex-wordmark", ".svg"]) do |file|
  file.write(File.binread("/tmp/svdex-wordmark.svg"))
  file.flush
  UploadCreator.new(file, "svdex-wordmark.svg", for_site_setting: true).create_for(admin.id)
end
raise "Could not install the SVDEX wordmark" unless logo.persisted?
SiteSetting.logo = logo.id
SiteSetting.logo_dark = logo.id
SiteSetting.mobile_logo = logo.id

category = Category.find_by(slug: "discussion") || Category.create!(
  name: "Discussion", slug: "discussion", color: "2396bf", text_color: "ffffff",
  user: Discourse.system_user,
)
SiteSetting.default_composer_category = category.id
SiteSetting.default_navigation_menu_categories = category.id.to_s
PluginStore.set("miscdex", "initial_setup_completed", true)
puts "Configured SVDEX categories, tags and the local administrator."
