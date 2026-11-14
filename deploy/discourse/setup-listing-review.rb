# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

category = Category.find(SiteSetting.svdex_listings_category_id)
raise "Expected Offerings category" unless category.slug == "offerings"
category.update!(topic_posting_review_mode: "everyone", reply_posting_review_mode: "no_one")
puts "Offerings: new topics require review; replies do not require category approval."
