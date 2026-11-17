# frozen_string_literal: true
# Native category configuration only; never import local product/pricing fixtures.
local = GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
staging = GlobalSetting.hostname == "staging.svdex.com" && ENV["SVDEX_STAGING_SETUP"] == "1" && SiteSetting.disable_emails == "yes" && SiteSetting.login_required && !SiteSetting.allow_new_registrations
explicit = ENV["SVDEX_CONFIGURE_UPGRADE"] == "1" || ENV["SVDEX_INITIAL_SETUP"] == "1"
abort "Explicit Pre-sales setup required" unless local || ((GlobalSetting.hostname == "svdex.com" || staging) && explicit)
actor = local ? User.find_by!(username: "svdex") : User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Active administrator required" unless actor&.admin? && actor.active?
Category.transaction do
  category = Category.find_by(id: SiteSetting.svdex_presales_category_id) || Category.find_by(slug: "pre-sales") || Category.new(user: actor)
  raise "Unexpected Pre-sales category" if category.persisted? && (category.slug != "pre-sales" || category.parent_category_id.present?)
  category.assign_attributes(name: "Pre-sales", slug: "pre-sales", color: "D9A441", text_color: "FFFFFF")
  category.set_permissions("everyone" => :full)
  category.save!
  category.update!(description: "Product pre-orders, early access and crowdfunding campaigns. Discuss pricing, what is included and expected delivery.",
    topic_posting_review_mode: "everyone", reply_posting_review_mode: "no_one")
  SiteSetting.svdex_presales_category_id = category.id
end
puts "Pre-sales configured as a separate public category with reviewed topics and native replies."
