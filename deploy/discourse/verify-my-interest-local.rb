# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def check_bid!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def bid_session(user = nil, password = nil)
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
before = [SiteSetting.svdex_bids_enabled, SiteSetting.svdex_interest_enabled]
begin
  SiteSetting.svdex_bids_enabled = true
  SiteSetting.svdex_interest_enabled = true
  User.transaction do
    password = SecureRandom.hex(24)
    users = 2.times.map do |i|
      User.create!(username: "history_#{SecureRandom.hex(5)}", email: "#{SecureRandom.hex(10)}@example.invalid", password: password,
        active: true, approved: true, trust_level: 2, admin: i == 1).tap { |u| u.email_tokens.update_all(confirmed: true) }
    end
    company = User.find_by!(username: "svdex-company")
    fund = User.find_by!(username: "svdex-fund-i")
    tag = Tag.find(company.custom_fields.fetch("svdex_company_tag_id")).name
    make_topic = ->(category) { PostCreator.create!(users[1], title: "Private history check #{SecureRandom.hex(6)}", raw: "An offering for isolated submission history checks.", category: category, tags: [tag], skip_validations: true, skip_jobs: true).topic }
    topic = make_topic.call(SiteSetting.svdex_public_offerings_category_id)
    restricted = make_topic.call(SiteSetting.svdex_private_offerings_category_id)
    bid_attrs = { organization: company, amount_cents: 125025, currency: "USD", proposed_terms: "Private proposed price", confirmed_at: Time.current, expires_at: 30.days.from_now }
    bid = DiscourseSvdex::OfferingBid.create!(bid_attrs.merge(user: users[0], topic: topic))
    hidden_bid = DiscourseSvdex::OfferingBid.create!(bid_attrs.merge(user: users[0], topic: restricted))
    other = DiscourseSvdex::OfferingBid.create!(bid_attrs.merge(user: users[1], topic: topic))
    interest_attrs = { user: users[0], organization: company, side: "buy", market: "either", amount_cents: 50000, currency: "USD", expires_at: 30.days.from_now }
    current = DiscourseSvdex::InterestIndication.create!(interest_attrs)
    expired = DiscourseSvdex::InterestIndication.create!(interest_attrs.merge(side: "sell", market: "secondary", expires_at: 1.day.ago))
    withdrawn = DiscourseSvdex::InterestIndication.create!(interest_attrs.merge(organization: fund, withdrawn_at: Time.current))
    guest, = bid_session
    member, headers = bid_session(users[0], password)
    staff, staff_headers = bid_session(users[1], password)
    path = "/listings/my-interest.json"
    guest.get path
    check_bid!(guest.response.status == 403, "history requires sign-in")
    member.get path
    check_bid!(member.response.status == 200, "owner can read history")
    data = member.response.parsed_body
    check_bid!(data["records"].length == 5 && data["records"].none? { |r| r["id"] == other.id && r["kind"] == "bid" }, "history only contains the signed-in member's records")
    check_bid!(member.response.headers["Cache-Control"].include?("no-store"), "history is never publicly cached")
    visible = data["records"].find { |r| r["kind"] == "bid" && r["id"] == bid.id }
    check_bid!(visible["can_edit"] && visible.dig("topic", "id") == topic.id, "accessible bid links to its offering and can be edited")
    hidden = data["records"].find { |r| r["kind"] == "bid" && r["id"] == hidden_bid.id }
    check_bid!(hidden["topic"].nil? && hidden["organization"].nil? && hidden["proposed_terms"].nil? && !hidden["can_edit"] && hidden["amount_cents"] == 125025, "lost private access redacts source details while retaining the owner's amount")
    staff.get path, params: { user_id: users[0].id, username: users[0].username }
    check_bid!(staff.response.parsed_body["records"].map { |r| [r["kind"], r["id"]] } == [["bid", other.id]], "staff cannot use history to impersonate another owner")
    %w[current expired withdrawn].each do |state|
      member.get path, params: { kind: "interest", status: state }
      check_bid!(member.response.parsed_body["records"].length == 1 && member.response.parsed_body["records"].all? { |r| r["status"] == state && r["kind"] == "interest" }, "#{state} and kind filters are exact")
    end
    [{ kind: "invalid" }, { status: "invalid" }, { page: "-1" }, { page: "1001" }, { page: "0 UNION" }].each do |args|
      member.get path, params: args
      check_bid!(member.response.status == 400, "invalid history filter or page is rejected")
    end
    topic.update!(closed: true)
    member.get path, params: { kind: "bid" }
    check_bid!(!member.response.parsed_body["records"].find { |r| r["id"] == bid.id }["can_edit"], "closed offerings cannot be edited from history")
    topic.first_post.update!(hidden: true)
    member.get path, params: { kind: "bid" }
    check_bid!(member.response.parsed_body["records"].find { |r| r["id"] == bid.id }["topic"].nil?, "hidden first posts are redacted")
    SiteSetting.svdex_bids_enabled = false
    SiteSetting.svdex_interest_enabled = false
    member.get path
    check_bid!(member.response.status == 200 && member.response.parsed_body["records"].none? { |r| r["can_edit"] }, "history remains readable with editing disabled")
    member.delete "/listings/my-interest/bid/#{other.id}.json", headers: headers
    check_bid!(member.response.status == 404 && other.reload.withdrawn_at.nil?, "withdrawal cannot affect another owner's bid")
    member.delete "/listings/my-interest/bid/#{hidden_bid.id}.json", headers: headers
    check_bid!(member.response.status == 200 && hidden_bid.reload.withdrawn_at.present?, "owner can withdraw after private access and feature access are lost")
    member.delete "/listings/my-interest/interest/#{current.id}.json", headers: headers
    check_bid!(member.response.status == 200 && current.reload.withdrawn_at.present?, "general interest can be withdrawn with feature disabled")
    # Equal timestamps and mixed table ids must not repeat or disappear across pages.
    time = Time.current.change(usec: 0)
    30.times do
      t = make_topic.call(SiteSetting.svdex_public_offerings_category_id)
      DiscourseSvdex::OfferingBid.create!(bid_attrs.merge(user: users[0], topic: t, updated_at: time))
    end
    member.get path
    first = member.response.parsed_body
    member.get path, params: { page: 1 }
    second = member.response.parsed_body
    keys = (first["records"] + second["records"]).map { |r| [r["kind"], r["id"]] }
    check_bid!(first["has_more"] && !second["has_more"] && keys.size == 35 && keys.uniq.size == 35, "mixed submissions paginate without duplicates at equal timestamps")
    raise ActiveRecord::Rollback
  end
ensure
  SiteSetting.svdex_bids_enabled, SiteSetting.svdex_interest_enabled = before
end
