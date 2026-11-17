# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
raise "Category rows should not include topic previews" unless SiteSetting.desktop_category_page_style == "categories_only" && SiteSetting.mobile_category_page_style == "categories_only"
raise "Separate Categories tab is still enabled" if SiteSetting.top_menu.split("|").include?("categories")
help = Category.find(SiteSetting.svdex_help_category_id)
raise "Feedback category name/slug incorrect" unless help.name == "Feedback" && help.slug == "feedback"
raise "Help no longer covers feedback" unless help.description.downcase.include?("feedback")
primary = [SiteSetting.svdex_listings_category_id.to_i, Category.find_by!(slug: "discussion").id, help.id]
raise "Default category navigation is incomplete" unless (primary - SiteSetting.default_navigation_menu_categories.split("|").map(&:to_i)).empty?
owner = User.find_by!(username: "svdex")
raise "Owner category pins missing" unless (primary - owner.secured_sidebar_category_ids).empty?
app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
%w[/categories /all-forums /discussion-forums].each do |path|
  app.get path
  raise "Directory route failed: #{path}" unless app.response.status == 200
end
app.get "/categories.json"
public_ids = app.response.parsed_body.fetch("category_list").fetch("categories").map { |row| row.fetch("id") }
raise "Private category appears in public directory" unless public_ids.sort == (primary + [SiteSetting.svdex_introductions_category_id.to_i, SiteSetting.svdex_events_category_id.to_i, SiteSetting.svdex_presales_category_id.to_i]).sort
app.get "/categories_and_latest.json"
raise "Overview native data failed" unless app.response.status == 200
rows = app.response.parsed_body.fetch("topic_list").fetch("topics")
raise "Overview exposes Help or Staff" if rows.any? { |row| [help.id, Category.find_by!(slug: "staff").id].include?(row["category_id"]) }
# Core tag routes must receive their main tag alongside added sector tags;
# otherwise core interprets returned tag metadata as a synonym redirect.
main_tag = Tag.find_by!(name: "svdex")
sector = Tag.find_by!(name: "finance")
app.get "/tags#{Category.find(SiteSetting.svdex_listings_category_id).url}/#{main_tag.slug}/#{main_tag.id}/l/latest.json", params: { tags: "#{main_tag.name} #{sector.name}", match_all_tags: true }
raise "Combined native tag query failed" unless app.response.status == 200
payload = app.response.parsed_body.fetch("topic_list")
raise "Main tag metadata missing" unless payload.fetch("tags").any? { |tag| tag["id"] == main_tag.id }
expected_topics = Topic.visible.secured(Guardian.new(nil)).listable_topics.where(category_id: DiscourseSvdex.offering_category_ids).joins(:tags).where(tags: { id: [main_tag.id, sector.id] }).group("topics.id").having("COUNT(DISTINCT tags.id) = 2").pluck(:id)
raise "Combined tag query lost matching offerings" unless payload.fetch("topics").map { |row| row["id"] }.sort == expected_topics.sort
payload.fetch("topics").each do |row|
  actual_tags = Topic.find(row.fetch("id")).tags.pluck(:id)
  raise "Tag/sector intersection ignored" unless [main_tag.id, sector.id].all? { |id| actual_tags.include?(id) }
end
puts "PASS native category data and combined Overview route, no separate Categories tab, public/private visibility, Feedback name and description, sidebar defaults and owner pins"
