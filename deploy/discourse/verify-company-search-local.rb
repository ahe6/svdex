# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
category = Category.find(SiteSetting.svdex_public_offerings_category_id)
app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
Post.transaction do
  company = "Aster Laboratories #{SecureRandom.hex(5)}"
  titles = ["#{company} — Seed", "#{company} — 2032 Bond"]
  titles.each { |title| PostCreator.create!(Discourse.system_user, title: title, raw: "Laboratory equipment development and operating plans.", category: category.id, skip_validations: true, skip_jobs: true) }
  hidden = PostCreator.create!(Discourse.system_user, title: "#{company} Private — Seed", raw: "Not a public listing.", category: category.id, skip_validations: true, skip_jobs: true).topic
  hidden.update!(visible: false)
  PostCreator.create!(Discourse.system_user, title: "#{company} Discussion", raw: "An ordinary discussion about laboratory equipment.", category: Category.find_by!(slug: "discussion").id, skip_validations: true, skip_jobs: true)
  app.get "/listings/companies.json", params: { q: company.downcase }
  raise "Autocomplete HTTP #{app.response.status}" unless app.response.status == 200
  raise "Suggestions contain offerings or hidden topics" unless JSON.parse(app.response.body)["companies"] == [{"name" => company}]
  [company, titles.first].each do |query|
    app.get "#{category.url}.json", params: { svdex_company: query }
    actual = JSON.parse(app.response.body).fetch("topic_list").fetch("topics").map { |t| t["title"] }.sort
    raise "Company did not match both offerings" unless actual == titles.sort
  end
  app.get "/listings/companies.json", params: { q: "%" }
  raise "Wildcard was not literal" unless JSON.parse(app.response.body)["companies"].empty?
  app.get "/listings/companies.json", params: { q: "x" * 121 }
  raise "Oversized query accepted" unless app.response.status == 400
  puts "PASS company-only suggestions deduplicate offerings, company filters match all rounds, legacy full-title queries work, and hidden/other-category topics stay excluded"
  raise ActiveRecord::Rollback
end
