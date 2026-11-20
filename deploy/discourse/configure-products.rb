# frozen_string_literal: true
# Creates only the native category; never publishes local product fixtures.
local = GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
staging = GlobalSetting.hostname == "staging.svdex.com" && ENV["SVDEX_STAGING_SETUP"] == "1" && SiteSetting.disable_emails == "yes" && SiteSetting.login_required && !SiteSetting.allow_new_registrations
explicit = ENV["SVDEX_CONFIGURE_UPGRADE"] == "1" || ENV["SVDEX_INITIAL_SETUP"] == "1"
abort "Explicit Products setup required" unless local || ((GlobalSetting.hostname == "svdex.com" || staging) && explicit)
actor = local ? User.find_by!(username: "svdex") : User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Active administrator required" unless actor&.admin? && actor.active?
Category.transaction do
  category = Category.find_by(id: SiteSetting.svdex_products_category_id) || Category.find_by(slug: "products") || Category.new(user: actor)
  raise "Unexpected Products category" if category.persisted? && (category.slug != "products" || category.parent_category_id.present?)
  category.assign_attributes(name: "Products", slug: "products", color: "2396BF", text_color: "FFFFFF")
  category.set_permissions("everyone" => :full, "staff" => :full)
  category.save!
  category.update!(description: "Discover products, explore what they do and discuss them with their makers. Product pages stay useful before and after launch.",
    topic_posting_review_mode: "everyone", reply_posting_review_mode: "no_one")
  SiteSetting.svdex_products_category_id = category.id
  presales = Category.find_by(id: SiteSetting.svdex_presales_category_id)
  if presales
    raise "Unexpected Pre-sales parent" unless presales.slug == "pre-sales" && [nil, category.id].include?(presales.parent_category_id)
    presales.update!(parent_category_id: category.id)
  end
end
puts "Products configured for reviewed submissions and public discussion."
