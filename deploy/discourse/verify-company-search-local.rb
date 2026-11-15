# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
category = Category.find(SiteSetting.svdex_public_offerings_category_id)
app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
Post.transaction do
  company = "Aster Laboratories #{SecureRandom.hex(5)}"
  security = "Convertible Note #{SecureRandom.hex(5)}"
  titles = ["#{company} — #{security}", "#{company} — 2032 Bond"]
  titles.each { |title| PostCreator.create!(Discourse.system_user, title: title, raw: "Laboratory equipment development and operating plans.", category: category.id, skip_validations: true, skip_jobs: true) }
  hidden = PostCreator.create!(Discourse.system_user, title: "#{company} Private — Seed", raw: "Not a public listing.", category: category.id, skip_validations: true, skip_jobs: true).topic
  hidden.update!(visible: false)
  PostCreator.create!(Discourse.system_user, title: "#{company} Discussion", raw: "An ordinary discussion about laboratory equipment.", category: Category.find_by!(slug: "discussion").id, skip_validations: true, skip_jobs: true)
  app.get "/listings/companies.json", params: { q: company.downcase }
  raise "Autocomplete HTTP #{app.response.status}" unless app.response.status == 200
  raise "Suggestions contain offerings or hidden topics" unless JSON.parse(app.response.body)["companies"] == [{"name" => company}]
  [company, titles.first].each do |query|
    app.get "#{category.url}.json", params: { svdex_company: query }
    payload = JSON.parse(app.response.body).fetch("topic_list")
    raise "Wrong offering count" unless payload.fetch("svdex_offering_count") == 2
    actual = payload.fetch("topics").map { |t| t["title"] }.sort
    raise "Company did not match both offerings" unless actual == titles.sort
  end
  app.get "#{category.url}.json", params: { svdex_company: security }
  payload = JSON.parse(app.response.body).fetch("topic_list")
  raise "Security title search did not narrow offerings" unless payload.fetch("svdex_offering_count") == 1 && payload.fetch("topics").map { |t| t["title"] } == [titles.first]
  page = TopicQuery.new(nil, category: category.id, svdex_company: company, per_page: 1).list_latest
  raise "Count limited to first page" unless page.topics.size == 1 && page.topics.first.attributes.fetch("svdex_offering_count").to_i == 2
  private_category = Category.find(SiteSetting.svdex_private_offerings_category_id)
  PostCreator.create!(Discourse.system_user, title: "#{company} — Private round", raw: "Private financing discussion.", category: private_category.id, skip_validations: true, skip_jobs: true)
  parent = Category.find(SiteSetting.svdex_listings_category_id)
  app.get "#{parent.url}.json", params: { svdex_company: company }
  raise "Count exposed private or unlisted offerings" unless JSON.parse(app.response.body).fetch("topic_list").fetch("svdex_offering_count") == 2
  app.get "#{category.url}.json", params: { svdex_company: "absent-#{SecureRandom.hex(8)}" }
  raise "Empty count must be zero" unless JSON.parse(app.response.body).fetch("topic_list").fetch("svdex_offering_count") == 0
  puts "PASS offering counts respect filtering, pagination, empty results and private visibility; security names are searchable"
  app.get "/listings/companies.json", params: { q: "%" }
  raise "Wildcard was not literal" unless JSON.parse(app.response.body)["companies"].empty?
  app.get "/listings/companies.json", params: { q: "x" * 121 }
  raise "Oversized query accepted" unless app.response.status == 400
  puts "PASS company-only suggestions deduplicate offerings, company filters match all rounds, legacy full-title queries work, and hidden/other-category topics stay excluded"
  raise ActiveRecord::Rollback
end
