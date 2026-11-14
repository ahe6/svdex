abort "This installer is only for localhost:4080" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
existing = Theme.find_by(name: "SVDEX Sidebar", component: true)
component = RemoteTheme.import_theme_from_directory("/tmp/miscdex-sidebar", theme_id: existing&.id)
raise component.errors.full_messages.join(", ") unless component.persisted? && component.errors.empty?
parent = Theme.find(SiteSetting.default_theme_id)
parent.child_theme_ids = (parent.child_theme_ids + [component.id]).uniq
parent.save!
puts "Installed SVDEX Sidebar component #{component.id} on #{parent.name}."

# Companies is a regular first link in the native Community navigation, not a
# separate custom section. Preserve every other native/user-edited link.
SidebarSection.transaction do
  section = SidebarSection.find_by!(section_type: :community, public: true)
  # The theme API now owns primary directory/feed links and active states.

  # Account links use their native classes in the API registration order below Home.
  %w[/about /faq /guidelines /rules /conduct /badges /tags /u /my/activity /my/messages /review /admin /new-invite].each do |value|
    link = section.sidebar_urls.find_by(value: value)
    section.sidebar_section_links.where(linkable: link).destroy_all if link
  end
  # Primary destinations use native API links, with query-aware active states.
  section.sidebar_urls.where(value: ["/companies", "/latest"]).each do |entry|
    section.sidebar_section_links.where(linkable: entry).destroy_all
  end
  section.sidebar_urls.find_by!(value: "/g").update!(segment: :secondary)
end

# Overview combines categories and tags; no separate Categories tab.
SiteSetting.top_menu = SiteSetting.top_menu.split("|").reject { |item| item == "categories" }.join("|")
# Keep native category rows without topic previews in the combined directory.
SiteSetting.desktop_category_page_style = "categories_only"
SiteSetting.mobile_category_page_style = "categories_only"
TranslationOverride.upsert!("en", "js.badges.title", "Achievements")

# Restore a useful native Categories section for new visitors. Seed the local
# owner's primary links once, preserving existing pins and later user edits.
primary_categories = [SiteSetting.svdex_listings_category_id.to_i, Category.find_by!(slug: "discussion").id, SiteSetting.svdex_help_category_id.to_i].select(&:positive?).uniq
SiteSetting.default_navigation_menu_categories = primary_categories.join("|")
if primary_categories.length == 3 && !PluginStore.get("svdex", "category_navigation_seeded")
  owner = User.find_by!(username: "svdex")
  SidebarSectionLinksUpdater.update_category_section_links(owner, category_ids: (primary_categories + owner.secured_sidebar_category_ids).uniq)
  PluginStore.set("svdex", "category_navigation_seeded", true)
end
