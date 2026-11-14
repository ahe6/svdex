# frozen_string_literal: true
# Local layout fixtures: one through four desktop financial lines, all issued
# by the same company. Existing SAFE and note topics supply two and four lines.
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_public_offerings_category_id)
company = User.find_by!(username: "svdex-company")
fixtures = [
  {
    source: "svdex-ordinary-shares", title: "SVDEX — Ordinary Shares",
    summary: "Secondary ordinary shares in a company building private-market research tools.",
    raw: "Ordinary shares in SVDEX for long-term shareholders. Company-wide funding is shown here; pricing and transfer terms have not been disclosed.",
    fields: { svdex_total_funding: "USD 2,000,000" },
  },
  {
    source: "svdex-series-a-preferred", title: "SVDEX — Series A Preferred",
    summary: "Preferred equity supporting company research, discovery and market-data expansion.",
    raw: "Preferred shares in SVDEX to expand company research and private-market data coverage. The proposed round targets USD 5 million at a USD 20 million post-money valuation.",
    fields: { svdex_total_funding: "USD 2,000,000", svdex_post_money_valuation_usd: "20000000", svdex_offering_size: "USD 5,000,000" },
  },
]
fixtures.each do |fixture|
  existing = TopicCustomField.find_by(name: "svdex_source_id", value: fixture[:source])
  topic = Topic.find_by(id: existing&.topic_id)
  unless topic
    post = PostCreator.create!(company, {
      title: fixture[:title], raw: fixture[:raw], category: category.id,
      tags: %w[svdex finance], svdex_summary: fixture[:summary],
      skip_validations: true, skip_jobs: false,
    }.merge(fixture[:fields]))
    topic = post.topic
    topic.custom_fields["svdex_source_id"] = fixture[:source]
    topic.save_custom_fields
  end
  raise "Unexpected category or author" unless topic.category_id == category.id && topic.first_post.user_id == company.id
  puts "#{fixture[:title]}: #{topic.url}"
end
puts "Offering layout fixtures ready; stable source keys preserve existing edits."
