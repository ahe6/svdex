# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def assert_market!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def market_login(user, password)
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.remote_addr = "198.18.#{SecureRandom.random_number(256)}.#{SecureRandom.random_number(254) + 1}"
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: user.username, password: password }, headers: headers
  raise "Test login failed #{app.response.status}" unless app.response.status == 200
  [app, headers]
end

publication_before = SiteSetting.svdex_interest_public_totals
begin
SiteSetting.svdex_interest_public_totals = false
owner = User.find_by!(username: "svdex")
companies = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
introductions = Category.find(SiteSetting.svdex_introductions_category_id)
assert_market!(companies.allow_membership_requests && !companies.public_admission && companies.group_users.exists?(owner: true), "native company applications require manual owner approval")
assert_market!(!DiscourseSvdex::CompanyDirectory.company?(owner), "staff group ownership does not classify an administrator as a company")
assert_market!(Category.find(SiteSetting.svdex_private_offerings_category_id).name == "Private offerings", "private child uses its approved display name without changing its ID")

ActiveRecord::Base.transaction do
  password = SecureRandom.hex(24)
  create_user = ->(admin = false) do
    user = User.create!(username: "market_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: 1, admin: admin)
    user.email_tokens.update_all(confirmed: true)
    user
  end
  staff_user, first, second = create_user.call(true), create_user.call, create_user.call
  staff, staff_headers = market_login(staff_user, password)
  a, a_headers = market_login(first, password)
  b, b_headers = market_login(second, password)
  guest = ActionDispatch::Integration::Session.new(Rails.application)
  guest.host! "localhost"

  reason = "SVDEX company application · v1\n\nCompany or project: New research project\nAuthorized representative: Founder\nDescription: Research tools\nWebsite: Not provided\nAuthority confirmed: Yes"
  a.post "/groups/#{companies.name}/request_membership.json", params: { reason: reason }, headers: a_headers
  assert_market!(a.response.status == 200 && GroupRequest.exists?(group: companies, user: first) && !companies.users.exists?(first.id), "company application enters native pending requests without self-enrollment")
  request_url = a.response.parsed_body.fetch("relative_url")
  guest.get "#{request_url}.json"
  assert_market!([403, 404].include?(guest.response.status), "application details remain private")
  duplicate_rejected = false
  ActiveRecord::Base.transaction(requires_new: true) do
    begin
      GroupMembershipRequester.request(first.guardian, companies, reason)
    rescue GroupMembershipRequester::AlreadyRequested
      duplicate_rejected = true
      raise ActiveRecord::Rollback
    end
  end
  assert_market!(duplicate_rejected && GroupRequest.where(group: companies, user: first).count == 1, "duplicate native applications cannot create duplicate pending requests")
  b.put "/groups/#{companies.id}/handle_membership_request.json", params: { user_id: first.id, accept: true }, headers: b_headers
  assert_market!(b.response.status == 403, "ordinary applicants cannot approve applications")
  staff.put "/groups/#{companies.id}/handle_membership_request.json", params: { user_id: first.id }, headers: staff_headers
  assert_market!(staff.response.status == 200 && !GroupRequest.exists?(group: companies, user: first) && !companies.users.exists?(first.id), "native rejection clears the request without granting company membership")
  a.post "/groups/#{companies.name}/request_membership.json", params: { reason: "Unstructured request for staff review" }, headers: a_headers
  assert_market!(a.response.status == 200 && !companies.users.exists?(first.id), "malformed structured text still needs staff review and cannot trigger automatic approval")
  staff.put "/groups/#{companies.id}/handle_membership_request.json", params: { user_id: first.id, accept: true }, headers: staff_headers
  assert_market!(staff.response.status == 200 && companies.users.exists?(first.id), "native owner approval supports a company with no financial or incorporation fields")
  # Existing approved representatives can submit an additional organization to
  # the same reviewers through native private messages, without re-enrollment.
  a.get "/groups/#{companies.name}/members.json", params: { limit: 1 }
  owners = a.response.parsed_body.fetch("owners").map { |owner| owner.fetch("username") }
  assert_market!(a.response.status == 200 && owners.any?, "approved applicants can find their native application reviewers")
  fund_reason = "SVDEX fund application · v1\n\n**Fund:** Research Capital\n**Authorized representative:** Investment Manager\n**Description:** An investment fund supporting scientific infrastructure companies through a diversified portfolio of early-stage equity positions. Its investment committee assesses business quality, portfolio concentration, follow-on reserves, and the needs of research equipment manufacturers.\n**Website:** Not provided\n**Authority confirmed:** Yes"
  a.post "/posts.json", params: { archetype: "private_message", target_recipients: owners.join(","), title: "Fund application: Research Capital", raw: fund_reason }, headers: a_headers
  assert_market!(a.response.status == 200, "approved company representatives can submit another application as a native private message: #{a.response.status} #{a.response.body.first(400) unless a.response.status == 200}")
  staff.post "/posts.json", params: { archetype: "private_message", target_recipients: staff_user.username, title: "Company application: Portfolio Research", raw: "A staff-managed organization profile application for Portfolio Research, submitted to its reviewer inbox. The organization develops quantitative data systems for research teams and seeks a public directory profile. Authority to represent the organization is confirmed, and profile publication remains a separate manual review action." }, headers: staff_headers
  assert_market!(staff.response.status == 200, "staff application works when the submitter is also the only reviewer: #{staff.response.status}")
  application_id = a.response.parsed_body.fetch("topic_id")
  guest.get "/t/#{application_id}.json"
  assert_market!([403, 404].include?(guest.response.status), "additional organization applications remain private")
  assert_market!(companies.users.exists?(first.id) && !GroupRequest.exists?(group: companies, user: first), "additional applications do not create duplicate memberships or requests")
  private_group = Group.find_by!(name: SiteSetting.svdex_private_offerings_group_name)
  assert_market!(!private_group.users.exists?(first.id) && !UserBadge.exists?(user: first, badge: Badge.find_by!(name: "Verified Accredited Investor")), "company approval grants neither private-deal access nor accreditation")
  assert_market!(!second.guardian.can_create_topic_on_category?(introductions) && staff_user.guardian.can_create_topic_on_category?(introductions), "unapproved accounts cannot submit official organization updates")
  discussion = Category.find_by!(slug: "discussion")
  offering_category = Category.find(SiteSetting.svdex_public_offerings_category_id)
  intro = PostCreator.create!(staff_user, title: "New research organization #{SecureRandom.hex(4)}", raw: "An approved organization introduction for community discussion.", category: introductions.id, skip_validations: true, skip_jobs: true).topic
  conversation = PostCreator.create!(staff_user, title: "Research discussion #{SecureRandom.hex(4)}", raw: "Independent community research conversation remains in Discussions.", category: discussion.id, skip_validations: true, skip_jobs: true).topic
  offering = PostCreator.create!(staff_user, title: "Research offering #{SecureRandom.hex(4)}", raw: "Offering topic for checking feed scope and moderation behavior.", category: offering_category.id, skip_validations: true, skip_jobs: true).topic
  [intro, conversation, offering].each { |topic| TopTopic.create!(topic: topic, all_score: 100_000, daily_score: 100_000) }
  [nil, first, staff_user].each do |viewer|
    query = TopicQuery.new(viewer, per_page: 100)
    [query.list_latest, query.list_top_for(:all)].each do |list|
      ids = list.topics.map(&:id)
      assert_market!(ids.include?(intro.id) && ids.include?(offering.id) && !ids.include?(conversation.id) && !ids.include?(introductions.topic_id), "Home Latest/Top allowlist runs before pagination for #{viewer&.admin? ? 'staff' : viewer ? 'members' : 'guests'}")
    end
  end
  assert_market!(TopicQuery.new(nil, category: discussion.id).list_latest.topics.map(&:id).include?(conversation.id), "Discussions remain available in native category browsing")

  org = User.find_by!(username: "svdex-company")
  # Keep this arithmetic scenario independent of local visual fixtures.
  DiscourseSvdex::InterestIndication.where(organization: org).delete_all
  other_org = User.find_by!(username: "northstar")
  path = "/listings/interests/#{org.id}"
  payload = ->(amount, market = "either", more = {}) { { interest: { amount: amount, market: market, currency: "USD", confirmation: "nonbinding" }.merge(more) } }
  a.put "#{path}/buy.json", params: payload.call("100.25"), headers: a_headers
  assert_market!(a.response.status == 200 && DiscourseSvdex::InterestIndication.find_by!(user: first, organization: org, side: "buy").amount_cents == 10025, "private nonbinding interest records exact USD cents without an open offering")
  row_id = DiscourseSvdex::InterestIndication.find_by!(user: first, organization: org, side: "buy").id
  a.put "#{path}/buy.json", params: payload.call("150.00"), headers: a_headers
  assert_market!(a.response.status == 200 && DiscourseSvdex::InterestIndication.where(user: first, organization: org, side: "buy").pluck(:id) == [row_id], "revisions replace the canonical entity-side record instead of double-counting")
  b.put "#{path}/buy.json", params: payload.call("50.00"), headers: b_headers
  staff.get "#{path}.json"
  assert_market!(staff.response.status == 200 && staff.response.parsed_body.dig("totals", "buy") == 20000, "staff preview totals derive from actual current records")
  a.get "#{path}.json"
  assert_market!(a.response.status == 200 && a.response.parsed_body["totals"].nil? && a.response.parsed_body.fetch("records").size == 1 && a.response.parsed_body.fetch("records").all? { |r| r["username"].nil? }, "members see only their own indications, without other investors or aggregate totals")
  guest.get "#{path}.json"
  assert_market!(guest.response.status == 403, "guest requests cannot read investor records")
  a.put "#{path}/sell.json", params: payload.call("25.00", "primary"), headers: a_headers
  assert_market!(a.response.status == 400 && !DiscourseSvdex::InterestIndication.exists?(user: first, organization: org, side: "sell"), "sell interest must explicitly represent secondary sales")
  a.put "#{path}/sell.json", params: payload.call("25.00", "secondary"), headers: a_headers
  assert_market!(a.response.status == 200, "secondary sell interest stays separate from buy interest")
  %w[-1 1.001 NaN 1e9].each do |amount|
    a.put "#{path}/buy.json", params: payload.call(amount), headers: a_headers
    assert_market!(a.response.status == 400, "server rejects malformed amount #{amount}")
  end
  a.put "#{path}/buy.json", params: payload.call("1", "either", currency: "EUR"), headers: a_headers
  assert_market!(a.response.status == 400, "other currencies require an explicit conversion design rather than invented FX values")
  a.delete "#{path}/buy.json", headers: a_headers
  assert_market!(a.response.status == 200, "investors can withdraw their current indication")
  DiscourseSvdex::InterestIndication.find_by!(user: second, organization: org, side: "buy").update!(expires_at: 1.minute.ago)
  staff.get "#{path}.json"
  assert_market!(staff.response.parsed_body.dig("totals", "buy") == 0 && staff.response.parsed_body.dig("totals", "sell") == 2500, "withdrawn and expired interest contributes zero while buy and sell remain separate")
  b.put "/listings/interests/#{other_org.id}/buy.json", params: payload.call("1000"), headers: b_headers
  staff.get "/listings/company-directory.json", params: { order: "svdex_buy_interest", limit: 1 }
  assert_market!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").first.fetch("id") == other_org.id, "numeric interest ordering happens on the server before pagination")
  [guest, a].each do |viewer|
    viewer.get "/listings/company-directory.json", params: { order: "svdex_buy_interest" }
    assert_market!(viewer.response.status == 403, "nonstaff sorting cannot infer private interest totals")
    viewer.get "/listings/company-directory.json"
    assert_market!(viewer.response.status == 200 && viewer.response.parsed_body.fetch("directory_items").none? { |r| r.fetch("user").fetch("svdex_company", {}).key?("interest_totals") }, "public/member directories do not expose staff interest totals")
  end
  # An offering link replaces the entity-level indication, never a second sum.
  linked = PostCreator.create!(staff_user, title: "Private opportunity #{SecureRandom.hex(4)}", raw: "Restricted investment context used for permission checks only.", category: SiteSetting.svdex_private_offerings_category_id, tags: ["svdex", "finance"], skip_validations: true, skip_jobs: true).topic
  a.put "#{path}/buy.json", params: payload.call("400", "primary", topic_id: linked.id), headers: a_headers
  assert_market!(a.response.status == 404, "an investor cannot attach interest to an inaccessible private opportunity")
  private_group.add(first)
  a.put "#{path}/buy.json", params: payload.call("400", "primary", topic_id: linked.id), headers: a_headers
  assert_market!(a.response.status == 200 && DiscourseSvdex::InterestIndication.where(user: first, organization: org, side: "buy").count == 1, "permitted offering-linked interest replaces the same canonical entity indication")
  private_group.remove(first)
  a.get "#{path}.json"
  assert_market!(a.response.parsed_body.fetch("interest").find { |r| r["side"] == "buy" }["topic_id"].nil?, "losing access hides restricted opportunity references even in personal records")
  a.delete "#{path}/buy.json", headers: a_headers
  assert_market!(a.response.status == 200, "withdrawal remains possible after losing private opportunity access")
  SiteSetting.svdex_interest_enabled = false
  a.get "#{path}.json"
  assert_market!(a.response.status == 404, "interest recording remains behind its release flag")
  a.delete "#{path}/sell.json", headers: a_headers
  assert_market!(a.response.status == 200, "withdrawal remains possible when new interest recording is disabled")
  raise ActiveRecord::Rollback
end
SiteSetting.refresh!
puts "Marketplace flow checks complete; all request, topic, account and interest test records rolled back."

ensure
  SiteSetting.svdex_interest_public_totals = publication_before
end
