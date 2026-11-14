# frozen_string_literal: true
# Local layout fixture only; never package this as production content.
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_private_offerings_category_id)
raise "Category must remain private" unless category.read_restricted?
issuer = User.find_by!(username: "svdex-company")
source = "svdex-private-seed-preferred"
existing = TopicCustomField.find_by(name: "svdex_source_id", value: source)&.topic
if existing
  raise "Unexpected fixture category or author" unless existing.category_id == category.id && existing.first_post.user_id == issuer.id
  topic = existing
else
  post = PostCreator.create!(issuer,
    title: "SVDEX — Seed Preferred",
    raw: "Seed preferred equity supporting company research, discovery and private-market data infrastructure.\n\nThe offering targets USD 1 million at a USD 8 million post-money valuation, with a USD 10,000 minimum investment. USD 250,000 has been raised in this offering.\n\nQuestions and company updates can be discussed in this thread.",
    category: category.id, tags: %w[svdex finance],
    svdex_summary: "Company research and discovery tools for private capital markets.",
    svdex_post_money_valuation_usd: "8000000", svdex_offering_size: "USD 1000000",
    svdex_funds_raised: "USD 250000", svdex_minimum: "USD 10000",
    svdex_total_funding: "USD 2000000", skip_validations: true, skip_jobs: false)
  topic = post.topic
  topic.custom_fields["svdex_source_id"] = source
  topic.save_custom_fields
end
raise "Private offering must be hidden from guests" if Guardian.new.can_see?(topic)
puts "Private offering ready: #{topic.url}"
