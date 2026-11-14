# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find_by(id: SiteSetting.svdex_listings_category_id) || Category.find_by(slug: "offerings") || Category.find_by(slug: "listings") || Category.create!(
  name: "Offerings", slug: "offerings", color: "0088CC", text_color: "FFFFFF", user: Discourse.system_user,
)
category.update!(name: "Offerings", slug: "offerings")
SiteSetting.svdex_listings_category_id = category.id
SiteSetting.tagging_enabled = true
puts "Offerings category: #{category.url} (native topics)."
