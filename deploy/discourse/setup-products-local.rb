# frozen_string_literal: true
# Local catalog fixtures only; never include this in production configuration.
abort "Local fixtures only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_products_category_id)
[
  ["SVDEX Research", "svdex-company", %w[svdex finance], "Company research and private-market data in one workspace.",
    "Explore company profiles, follow updates and compare opportunities across private markets.", "SVDEX Research — Annual early access"],
  ["Northstar Pocket Spectrometer", "northstar", %w[northstar hardware], "Pocket optical spectrometer for field measurements and laboratory research.",
    "A portable instrument for collecting optical measurements outside a traditional laboratory setup.", "Northstar Pocket Spectrometer — First production run"],
].each do |title, username, tags, summary, description, campaign_title|
  next if Topic.exists?(title: title, category_id: category.id)
  author = User.find_by!(username: username)
  campaign = Topic.find_by(title: campaign_title, category_id: SiteSetting.svdex_presales_category_id)
  links = ["[Company profile](/u/#{username}/summary)"]
  links << "[Pre-sale campaign](/t/#{campaign.slug}/#{campaign.id})" if campaign
  links << "[Visit SVDEX](https://svdex.com)" if username == "svdex-company"
  PostCreator.create!(author, title: title, raw: "#{summary}\n\n#{description}\n\n#{links.join(' · ')}\n\nUse this thread for product questions, feedback and updates.",
    category: category.id, tags: tags, skip_validations: true, skip_jobs: true)
end
puts "Local product catalog ready."

# The product and its campaign share one durable native tag.
group = TagGroup.find_by_name_insensitive("Products") || TagGroup.create!(name: "Products")
{
  "svdex-research" => ["SVDEX Research", "SVDEX Research — Annual early access"],
  "northstar-pocket-spectrometer" => ["Northstar Pocket Spectrometer", "Northstar Pocket Spectrometer — First production run"],
}.each do |name, titles|
  tag = Tag.find_by(name: name) || Tag.create!(name: name)
  group.tags << tag unless group.tags.exists?(tag.id)
  Topic.where(title: titles, category_id: [category.id, SiteSetting.svdex_presales_category_id]).find_each do |topic|
    topic.tags << tag unless topic.tags.exists?(tag.id)
  end
end
puts "Shared product/campaign tags ready."
