# Local-only installation of the SVDEX theme. No hosted configuration is changed.
abort "Appearance installation is only for localhost:4080" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

root = "/tmp/miscdex-appearance"
shared = File.read("#{root}/common.scss")
sidebar = Theme.find_by!(name: "SVDEX Sidebar", component: true)
admin = User.find_by!(username: "svdex")
# Use core palette definitions instead of the retired SVDEX color overrides.
schemes = {}
{ "light" => "Light", "dark" => "Dark" }.each do |mode, name|
  schemes[mode] = ColorScheme.find_by(name: "Discourse #{name}") || ColorScheme.create_from_base(
    name: "Discourse #{name}", base_scheme_id: ColorScheme::NAMES_TO_ID_MAP.fetch(name), colors: {},
  )
  raise schemes[mode].errors.full_messages.join(", ") unless schemes[mode].persisted?
end

theme = Theme.find_by(name: "SVDEX", component: false) || Theme.create!(name: "SVDEX", user_id: admin.id)
theme.color_scheme_id = schemes.fetch("light").id
theme.dark_color_scheme_id = schemes.fetch("dark").id
theme.user_selectable = true
theme.enabled = true
theme.child_theme_ids = (theme.child_theme_ids + [sidebar.id]).uniq
theme.set_field(target: :common, name: "scss", value: shared)
theme.save!
setting = Themes::ThemeSiteSettingManager.call(
  guardian: admin.guardian,
  params: { theme_id: theme.id, name: "enable_welcome_banner", value: false },
)
raise "Could not configure welcome banner" unless setting.success?

# Native <picture> logos follow forced modes and device preference directly.
require "tempfile"
wordmark = File.read("#{root}/wordmark.svg")
{ light: wordmark.sub('fill="#f2f4fb"', 'fill="#282b2e"'), dark: wordmark }.each do |mode, data|
  upload = Upload.find_by(sha1: Digest::SHA1.hexdigest(data))
  upload ||= Tempfile.create(["svdex-wordmark-#{mode}", ".svg"]) do |file|
    file.write(data)
    file.flush
    UploadCreator.new(file, "svdex-wordmark-#{mode}.svg", for_site_setting: true).create_for(admin.id)
  end
  raise "Could not install #{mode} wordmark" unless upload.persisted?
  if mode == :light
    SiteSetting.logo = upload.id
    SiteSetting.mobile_logo = upload.id
  else
    SiteSetting.logo_dark = upload.id
    SiteSetting.mobile_logo_dark = upload.id
  end
end

SiteSetting.enable_powered_by_discourse = false
SiteSetting.interface_color_selector = "sidebar_footer"
TranslationOverride.upsert!("en", "js.sidebar.footer.interface_color_selector.auto", "System")
SiteSetting.default_theme_id = theme.id

# Retain earlier candidates for recovery, but remove their separate choices.
Theme.where(name: ["SVDEX Graphite", "SVDEX Paper", "SVDEX Ink"], component: false).each do |candidate|
  candidate.update!(enabled: false, user_selectable: false)
end
Theme.find(Theme::CORE_THEMES.fetch("foundation")).update!(user_selectable: false)

puts JSON.pretty_generate(
  theme: theme.name, theme_id: theme.id, url: "http://localhost:4080/latest",
  light_color_scheme_id: schemes.fetch("light").id,
  dark_color_scheme_id: schemes.fetch("dark").id,
  color_selector: SiteSetting.interface_color_selector,
)
