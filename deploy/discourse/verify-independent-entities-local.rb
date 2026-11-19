# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
DiscourseSvdex::Prototypes::CompanyProfiles.setup!
def entity_assert!(value, label)
  raise label unless value
  puts "PASS #{label}"
end
model = DiscourseSvdex::Prototypes::CompanyProfileRecord
model.transaction do
  staff = User.find_by!(username: "svdex")
  password = SecureRandom.hex(24)
  member = User.create!(username: "entity_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true)
  member.email_tokens.update_all(confirmed: true)
  guest = ActionDispatch::Integration::Session.new(Rails.application)
  guest.host! "localhost"
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: member.username, password: password }, headers: headers
  person = model.create!(kind: "people", slug: "researcher-#{SecureRandom.hex(4)}", name: "Alex Rivera", summary: "Previously led robotics research at Harbor Instruments.", listed: true, facts: { "role" => "Partner", "location" => "United States" })
  fund = model.create!(kind: "funds", slug: "research-fund-#{SecureRandom.hex(4)}", name: "Harbor Research Fund", summary: "Early-stage research infrastructure investments.", listed: true, facts: { "aum_usd" => 25_000_000, "strategy_focus" => "VC", "vintage_year" => 2026, "fund_life" => "10-year term", "profile_key_people" => [{ "profile_id" => person.id, "role" => "Partner" }] })
  group = TagGroup.find_by_name_insensitive("People") || TagGroup.create!(name: "People")
  person_tag = Tag.create!(name: "researcher-#{SecureRandom.hex(4)}")
  group.tags << person_tag
  person.update!(facts: person.facts.merge("topic_tag_id" => person_tag.id))
  entity_assert!(DiscourseSvdex::Prototypes::CompanyProfiles.payload(person, Guardian.new)[:topics_url] == person_tag.url, "Related topics uses the person's native stable tag page")
  fund_tag = DiscourseSvdex::CompanyDirectory.tag_options("Companies", Guardian.new).first
  fund.update!(facts: fund.facts.merge("company_tag_id" => fund_tag[:id]))
  entity_assert!(DiscourseSvdex::Prototypes::CompanyProfiles.payload(fund, Guardian.new)[:topics_url] == fund_tag[:url], "fund related topics uses native company/entity tags across categories")
  guest.get "/fund-profiles/#{fund.slug}.json"
  data = guest.response.parsed_body
  entity_assert!(guest.response.status == 200 && data.dig("company", "aum_usd") == 25_000_000 && !data.key?("account"), "independent fund facts are public without a user account")
  entity_assert!(data.dig("company", "key_people", 0, "url") == person.profile_url, "fund key people link to independent person profiles")
  guest.get "/person-profiles/#{person.slug}.json"
  entity_assert!(guest.response.status == 200 && guest.response.parsed_body.dig("person", "organizations", 0, "url") == fund.profile_url, "person affiliations derive from explicit independent profile references")
  entity_assert!(!guest.response.body.include?("email") && !guest.response.parsed_body.key?("editor"), "public person profiles do not expose login or staff data")
  guest.get "/company-profiles/#{fund.slug}.json"
  entity_assert!(guest.response.status == 404, "company profile URLs cannot alias a fund")
  guest.get "/fund-profiles.json?name=Harbor&svdex_aum=10m_100m"
  entity_assert!(guest.response.status == 200 && guest.response.parsed_body.fetch("profiles").any? { |entry| entry.dig("profile", "id") == fund.id }, "independent fund search and AUM ranges use fund facts")
  guest.get "/person-profiles.json?svdex_organization=#{fund.id}&svdex_location=United%20States"
  entity_assert!(guest.response.status == 200 && guest.response.parsed_body.fetch("profiles").map { |entry| entry.dig("profile", "id") } == [person.id], "people filter by independent current organization and location")
  person_path = "/person-profiles/#{person.slug}.json"
  app.put person_path, params: { profile: { name: "Changed" } }, headers: headers
  entity_assert!(app.response.status == 403 && person.reload.name == "Alex Rivera", "ordinary members cannot rewrite curated person facts")
  reviewer = User.create!(username: "reviewer_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, admin: true)
  reviewer.email_tokens.update_all(confirmed: true)
  editor = ActionDispatch::Integration::Session.new(Rails.application)
  editor.host! "localhost"
  editor.get "/session/csrf.json"
  staff_headers = { "X-CSRF-Token" => editor.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  editor.post "/session.json", params: { login: reviewer.username, password: password }, headers: staff_headers
  editor.put person_path, params: { profile: { facts: { role: "Managing Partner" } } }, headers: staff_headers
  entity_assert!(editor.response.status == 200 && person.reload.facts["role"] == "Managing Partner", "staff edit professional facts without a fabricated user account")
  editor.put person_path, params: { profile: { facts: { net_worth: "$10M" } } }, headers: staff_headers
  entity_assert!(editor.response.status == 400 && person.reload.facts["net_worth"].nil?, "unsourced person net-worth claims cannot be saved")
  sourced = { net_worth: "$8M–$12M", net_worth_source: "https://example.org/research", net_worth_date: Date.current.iso8601, net_worth_basis: "Published estimate; uncertain and not liquid capital." }
  editor.put person_path, params: { profile: { facts: sourced } }, headers: staff_headers
  entity_assert!(editor.response.status == 200 && editor.response.parsed_body.dig("person", "net_worth", "value") == sourced[:net_worth], "person estimates retain their public source, date and basis")
  editor.put "/fund-profiles/#{fund.slug}.json", params: { profile: { facts: { aum_usd: "26000000" } } }, headers: staff_headers
  entity_assert!(editor.response.status == 200 && fund.reload.facts["aum_usd"] == 26_000_000, "staff update fund AUM through the native-style profile editor endpoint")
  app.put "/company-profile-interests/#{person.id}/buy.json", params: { interest: { amount: "1", currency: "USD", confirmation: "nonbinding" } }, headers: headers
  entity_assert!(app.response.status == 404, "person profiles do not accept company/fund financial interest")
  indication = DiscourseSvdex::InterestIndication.create!(company_profile_id: fund.id, user: member, side: "buy", market: "either", amount_cents: 12_345, currency: "USD", expires_at: 30.days.from_now)
  app.get "/company-profile-interests/#{fund.id}.json", headers: headers
  entity_assert!(app.response.status == 200 && app.response.parsed_body.fetch("interest").first["amount_cents"] == 12_345, "fund interest uses its own profile ID and preserves exact cents")
  app.get "/listings/my-interest.json", headers: headers
  entity_assert!(app.response.status == 200 && app.response.body.include?(fund.profile_url), "owner history links independent fund interest to the fund profile")
  [fund, person].each do |record|
    DiscourseSvdex::Prototypes::CompanyRelationships.record_discovery!(record, staff, { "provenance" => "discovered", "status" => "accepted", "contributor" => member.username, "listed_at" => record.created_at.iso8601(6), "reason" => "Reviewed public source and initial contribution" })
    history = DiscourseSvdex::Discoveries.history(member, Guardian.new(member), type: record.kind)
    entity_assert!(history[:records].any? { |entry| entry[:url] == record.profile_url && entry[:kind] == record.kind }, "#{record.kind} discovery history retains independent identity")
  end
  fund.update!(listed: false)
  guest.get person_path
  entity_assert!(guest.response.status == 200 && guest.response.parsed_body.dig("person", "organizations").empty?, "unpublished fund affiliations do not leak on public people profiles")
  guest.get "/fund-profiles/#{fund.slug}.json"
  entity_assert!(guest.response.status == 404, "unpublished fund profiles remain private")
  raise ActiveRecord::Rollback
end
puts "Independent entity checks complete; scenario records rolled back."
