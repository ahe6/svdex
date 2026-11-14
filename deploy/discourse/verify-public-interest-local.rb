# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
def assert_public_interest!(ok, message)
  raise message unless ok
  puts "PASS #{message}"
end
def interest_session(user = nil, password = nil)
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.remote_addr = "198.18.#{SecureRandom.random_number(256)}.#{SecureRandom.random_number(254) + 1}"
  return [app, {}] unless user
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: user.username, password: password }, headers: headers
  raise "Login failed" unless app.response.status == 200
  [app, headers]
end
settings_before = [SiteSetting.svdex_interest_enabled, SiteSetting.svdex_interest_public_totals, SiteSetting.svdex_interest_staff_preview]
begin
  SiteSetting.svdex_interest_enabled = true
  SiteSetting.svdex_interest_public_totals = true
  SiteSetting.svdex_interest_staff_preview = true
  User.transaction do
    password = SecureRandom.hex(24)
    people = 5.times.map { |i| User.create!(username: "aggregate_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(10)}@example.invalid", password: password, active: true, approved: true, trust_level: 2, admin: i == 4).tap { |user| user.email_tokens.update_all(confirmed: true) } }
    owner = User.find_by!(username: "svdex")
    company = User.find_by!(username: "svdex-company")
    other = User.find_by!(username: "northstar")
    fund = User.find_by!(username: "svdex-fund-i")
    indication = ->(user, organization, side, amount, consent = true, **attrs) {
      DiscourseSvdex::InterestIndication.create!({ user: user, organization: organization, side: side,
        market: side == "sell" ? "secondary" : "either", currency: "USD", amount_cents: amount,
        aggregate_consent_at: consent ? Time.current : nil, expires_at: 30.days.from_now }.merge(attrs))
    }
    indication.call(people[0], company, "buy", 10_000, false)
    buy = indication.call(people[1], company, "buy", 25_000)
    sell = indication.call(people[1], company, "sell", 10_000)
    indication.call(people[1], other, "buy", 100_000)
    indication.call(people[1], fund, "buy", 50_000)
    indication.call(people[2], company, "buy", 500_000, true, expires_at: 1.day.ago)
    indication.call(people[2], company, "sell", 900_000, true, withdrawn_at: 1.hour.ago)
    private_topic = PostCreator.create!(owner, title: "Private aggregate check #{SecureRandom.hex(4)}", raw: "Restricted terms must never contribute to public aggregate discovery.", category: SiteSetting.svdex_private_offerings_category_id, tags: [Tag.find(company.custom_fields.fetch("svdex_company_tag_id")).name], skip_validations: true, skip_jobs: true).topic
    indication.call(people[0], company, "sell", 999_999, true, topic: private_topic, source_was_restricted: true)
    assert_public_interest!(DiscourseSvdex::CompanyDirectory.interest_organization(private_topic, Guardian.new).nil?, "offering CTA never resolves a restricted topic for a guest")
    assert_public_interest!(DiscourseSvdex::CompanyDirectory.interest_organization(private_topic, owner.guardian).fetch(:id) == company.id, "offering CTA resolves its tagged company rather than its staff author")
    expected = { "buy" => 25_000, "sell" => 10_000 }
    [nil, people[0], people[4]].each do |viewer|
      result = DiscourseSvdex::InterestIndication.totals([company.id], Guardian.new(viewer))
      assert_public_interest!(result[company.id] == expected, "all viewers share totals excluding prior private, restricted, expired and withdrawn amounts")
    end
    guest, = interest_session
    member, headers = interest_session(people[3], password)
    guest.get "/listings/company-profile/#{company.username}.json"
    public_profile = guest.response.parsed_body
    assert_public_interest!(guest.response.status == 200 && public_profile.dig("company", "interest_totals") == expected, "guest profiles expose monetary aggregate values")
    assert_public_interest!(people.none? { |user| guest.response.body.include?(user.username) }, "public aggregates disclose no contributor identities or individual records")
    guest.get "/listings/company-directory.json", params: { kind: "companies", order: "svdex_buy_interest", limit: 1 }
    assert_public_interest!(guest.response.status == 200 && guest.response.parsed_body.fetch("directory_items").first.fetch("user").fetch("id") == other.id, "guest aggregate sorting applies before pagination")
    guest.get "/listings/company-directory.json", params: { kind: "companies", svdex_buy_interest: "under_1m", svdex_sell_interest: "under_1m", order: "svdex_buy_interest" }
    filtered_ids = guest.response.parsed_body.fetch("directory_items").map { |row| row.fetch("user").fetch("id") }
    assert_public_interest!(guest.response.status == 200 && filtered_ids == [company.id], "simultaneous buy/sell ranges use consented sums and exclude unknown amounts")
    guest.get "/listings/company-directory.json", params: { kind: "companies", svdex_buy_interest: "1m_10m" }
    assert_public_interest!(guest.response.status == 200 && guest.response.parsed_body.fetch("directory_items").empty?, "interest ranges compare USD boundaries against stored cents")
    guest.get "/listings/company-directory.json", params: { kind: "companies", svdex_buy_interest: "invalid" }
    assert_public_interest!(guest.response.status == 400, "invalid interest ranges are rejected")
    guest.get "/listings/company-directory.json", params: { kind: "funds", order: "svdex_buy_interest" }
    fund_row = guest.response.parsed_body.fetch("directory_items").find { |row| row.fetch("user").fetch("id") == fund.id }
    assert_public_interest!(fund_row.dig("user", "svdex_company", "interest_totals", "buy") == 50_000, "fund aggregate amounts use the same public contract")
    guest.get "/listings/interests/#{company.id}.json"
    assert_public_interest!([403, 404].include?(guest.response.status), "public totals never open the individual-record endpoint to guests")
    path = "/listings/interests/#{company.id}/buy.json"
    body = { interest: { amount: "450.75", currency: "USD", market: "either", confirmation: "nonbinding" } }
    member.put path, params: body, headers: headers
    assert_public_interest!(member.response.status == 200 && !member.response.parsed_body.dig("interest", "public_aggregate_consent"), "legacy private submission does not silently opt into publication")
    assert_public_interest!(DiscourseSvdex::InterestIndication.totals([company.id], Guardian.new)[company.id]["buy"] == 25_000, "unconsented amount stays out of the public sum")
    body[:interest][:confirmation] = "nonbinding-public-v1"
    member.put path, params: body, headers: headers
    assert_public_interest!(member.response.status == 200 && member.response.parsed_body.dig("interest", "public_aggregate_consent"), "public confirmation records explicit aggregate consent")
    assert_public_interest!(DiscourseSvdex::InterestIndication.totals([company.id], Guardian.new)[company.id]["buy"] == 70_075, "consented canonical record contributes exact cents without double-counting")
    member.delete path, headers: headers
    assert_public_interest!(member.response.status == 200 && DiscourseSvdex::InterestIndication.totals([company.id], Guardian.new)[company.id]["buy"] == 25_000, "withdrawal removes the contribution from public totals")
    body[:interest][:topic_id] = private_topic.id
    member.put path, params: body, headers: headers
    assert_public_interest!([403, 404].include?(member.response.status), "offering interest cannot be linked to an inaccessible topic")
    public_topic = PostCreator.create!(owner, title: "Public linked interest #{SecureRandom.hex(4)}", raw: "Public financing details linked to the tagged organization.", category: SiteSetting.svdex_public_offerings_category_id, tags: [Tag.find(company.custom_fields.fetch("svdex_company_tag_id")).name], skip_validations: true, skip_jobs: true).topic
    guest.get "/t/#{public_topic.id}.json"
    assert_public_interest!(guest.response.status == 200 && guest.response.parsed_body.dig("svdex_listing", "interest_organization", "id") == company.id, "offering topic exposes its authorized organization CTA independently of its author")
    body[:interest][:topic_id] = public_topic.id
    member.put path, params: body, headers: headers
    assert_public_interest!(member.response.status == 200 && member.response.parsed_body.dig("interest", "topic_id") == public_topic.id, "offering CTA saves a linked indication in the canonical company record")
    guest.get "/t/#{public_topic.id}.json"
    assert_public_interest!(guest.response.parsed_body.dig("svdex_listing", "interest_totals", "buy") == 45_075, "offering body excludes unlinked company interest")
    assert_public_interest!(DiscourseSvdex::InterestIndication.totals([company.id], Guardian.new)[company.id]["buy"] == 70_075, "company total includes the linked indication exactly once")
    member.get "/listings/interests/#{company.id}.json", params: { topic_id: public_topic.id }
    assert_public_interest!(member.response.status == 200 && member.response.parsed_body.dig("offering_totals", "buy") == 45_075 && member.response.parsed_body.dig("totals", "buy") == 70_075, "modal refresh keeps offering totals distinct from company totals")
    member.get "/listings/interests/#{company.id}.json", params: { topic_id: private_topic.id }
    assert_public_interest!(member.response.status == 404, "refresh cannot expose an inaccessible offering")
    member.get "/listings/interests/#{other.id}.json", params: { topic_id: public_topic.id }
    assert_public_interest!(member.response.status == 400, "refresh rejects an offering linked to another company")
    assert_public_interest!(DiscourseSvdex::InterestIndication.offering_totals(company.id, private_topic, owner.guardian).empty?, "offering totals retain restricted-origin publication exclusions")
    second_topic = PostCreator.create!(owner, title: "Other public financing #{SecureRandom.hex(4)}", raw: "A second financing for the same company must have its own displayed interest.", category: SiteSetting.svdex_public_offerings_category_id, tags: [Tag.find(company.custom_fields.fetch("svdex_company_tag_id")).name], skip_validations: true, skip_jobs: true).topic
    body[:interest][:topic_id] = second_topic.id
    body[:interest][:amount] = "300.00"
    member.put path, params: body, headers: headers
    guest.get "/t/#{public_topic.id}.json"
    first_total = guest.response.parsed_body.dig("svdex_listing", "interest_totals")
    guest.get "/t/#{second_topic.id}.json"
    assert_public_interest!(first_total.empty? && guest.response.parsed_body.dig("svdex_listing", "interest_totals", "buy") == 30_000, "moving an indication transfers it between offerings rather than pooling both")
    assert_public_interest!(DiscourseSvdex::InterestIndication.where(user: people[3], organization: company, side: "buy").count == 1 && DiscourseSvdex::InterestIndication.totals([company.id], Guardian.new)[company.id]["buy"] == 55_000, "moving interest preserves canonical deduplication in the company total")
    member.delete path, headers: headers
    guest.get "/t/#{second_topic.id}.json"
    assert_public_interest!(guest.response.parsed_body.dig("svdex_listing", "interest_totals", "buy") == 0 && DiscourseSvdex::InterestIndication.totals([company.id], Guardian.new)[company.id]["buy"] == 25_000, "withdrawal updates the offering and company totals without retaining its amount")
    second_topic.first_post.update!(hidden: true)
    member.put path, params: body, headers: headers
    assert_public_interest!(member.response.status == 404, "legacy interest cannot be refreshed against a hidden offering")
    member.get "/listings/interests/#{company.id}.json"
    assert_public_interest!(member.response.parsed_body.fetch("interest").find { |r| r["side"] == "buy" }["topic_id"].nil?, "hidden legacy offering identities are redacted from owner records")
    second_topic.first_post.update!(hidden: false)
    second_topic.update!(deleted_at: Time.current)
    member.put path, params: body, headers: headers
    assert_public_interest!(member.response.status == 404, "legacy interest rejects deleted offerings")
    company.update!(active: false)
    body[:interest].delete(:topic_id)
    member.put path, params: body, headers: headers
    assert_public_interest!(member.response.status == 404, "inactive organizations cannot receive new indications")
    company.update!(active: true)
    money = DiscourseSvdex::FinancialSubmissions
    assert_public_interest!(money.amount_cents!("90071992547409.91", currency: "USD") == 9_007_199_254_740_991 && money.amount_cents!("0.01", currency: "USD") == 1, "shared money parser preserves exact cent boundaries")
    ["0", "-1", "1e3", "01", "1.001", "90071992547409.92", 12.5, nil].each do |amount|
      rejected = begin; money.amount_cents!(amount, currency: "USD"); false; rescue Discourse::InvalidParameters; true; end
      assert_public_interest!(rejected, "shared money parser rejects ambiguous, nonpositive or out-of-range inputs")
    end
    buy.update!(expires_at: 1.day.ago)
    sell.update!(withdrawn_at: Time.current)
    assert_public_interest!(DiscourseSvdex::InterestIndication.totals([company.id], Guardian.new)[company.id] == { "buy" => 0, "sell" => 0 }, "measured zero remains distinct from never measured")
    raise ActiveRecord::Rollback
  end
ensure
  SiteSetting.svdex_interest_enabled, SiteSetting.svdex_interest_public_totals, SiteSetting.svdex_interest_staff_preview = settings_before
end
puts "Public aggregate checks complete; all test records rolled back."
