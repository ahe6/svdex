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
before = [SiteSetting.svdex_bids_enabled, SiteSetting.svdex_bids_staff_preview]
begin
  SiteSetting.svdex_bids_enabled = true
  SiteSetting.svdex_bids_staff_preview = true
  User.transaction do
    password = SecureRandom.hex(24)
    people = 3.times.map do |i|
      User.create!(username: "bid_#{SecureRandom.hex(5)}", email: "#{SecureRandom.hex(10)}@example.invalid", password: password,
        active: true, approved: true, trust_level: 2, admin: i == 2).tap { |u| u.email_tokens.update_all(confirmed: true) }
    end
    company = User.find_by!(username: "svdex-company")
    tag = Tag.find(company.custom_fields.fetch("svdex_company_tag_id")).name
    make_topic = ->(category) { PostCreator.create!(people[2], title: "Offering bid check #{SecureRandom.hex(6)}", raw: "An offering for isolated bid validation and permission checks.", category: category, tags: [tag], skip_validations: true, skip_jobs: true).topic }
    topic = make_topic.call(SiteSetting.svdex_public_offerings_category_id)
    other_topic = make_topic.call(SiteSetting.svdex_public_offerings_category_id)
    restricted = make_topic.call(SiteSetting.svdex_private_offerings_category_id)
    discussion = make_topic.call(Category.find_by!(slug: "discussion").id)
    guest, = bid_session
    member, headers = bid_session(people[0], password)
    stranger, stranger_headers = bid_session(people[1], password)
    staff, staff_headers = bid_session(people[2], password)
    path = "/listings/offering-bids/#{topic.id}.json"
    body = { bid: { amount: "1250.25", currency: "USD", proposed_terms: "$10 per share, subject to transfer approval", confirmation: "nonbinding-bid-v1" } }
    guest.get path
    check_bid!(guest.response.status == 403, "guests cannot read individual bids")
    guest.put path, params: body
    check_bid!(![200, 201].include?(guest.response.status), "guests cannot submit bids")
    member.put "/listings/offering-bids/#{restricted.id}.json", params: body, headers: headers
    check_bid!(member.response.status == 404, "private-offering bids require actual category access")
    member.put "/listings/offering-bids/#{discussion.id}.json", params: body, headers: headers
    check_bid!(member.response.status == 404, "ordinary discussions cannot accept bids")
    indication = DiscourseSvdex::InterestIndication.create!(user: people[0], organization: company, side: "buy", market: "either", amount_cents: 456_789, expires_at: 30.days.from_now)
    member.put path, params: body, headers: headers
    check_bid!(member.response.status == 200 && member.response.parsed_body.dig("bid", "amount_cents") == 125_025, "offering bid stores exact USD cents and proposed terms")
    row = DiscourseSvdex::OfferingBid.find_by!(user: people[0], topic: topic)
    check_bid!(row.organization_id == company.id && row.proposed_terms == body[:bid][:proposed_terms] && row.confirmed_at.present?, "issuer is resolved from the authorized offering and confirmation is recorded")
    check_bid!(indication.reload.amount_cents == 456_789 && indication.topic_id.nil?, "submitting a bid leaves general company interest unchanged")
    stranger.get path, headers: stranger_headers
    check_bid!(stranger.response.status == 200 && stranger.response.parsed_body["bid"].nil? && stranger.response.parsed_body["records"].empty?, "other members cannot read another investor's bids")
    staff.get path, headers: staff_headers
    check_bid!(staff.response.parsed_body["records"].one? && staff.response.parsed_body["records"][0]["username"] == people[0].username, "authorized staff can review bids only with the review flag")
    SiteSetting.svdex_bids_staff_preview = false
    staff.get path, headers: staff_headers
    check_bid!(staff.response.parsed_body["records"].empty?, "staff bid review defaults closed when its flag is off")
    SiteSetting.svdex_bids_staff_preview = true
    member.put path, params: {bid: body[:bid].merge(amount: "2000.00", proposed_terms: "At the stated valuation")}, headers: headers
    check_bid!(member.response.status == 200 && row.reload.amount_cents == 200_000 && DiscourseSvdex::OfferingBid.where(user: people[0], topic: topic).count == 1, "resubmitting updates one current bid per investor and offering")
    member.put "/listings/offering-bids/#{other_topic.id}.json", params: body, headers: headers
    check_bid!(member.response.status == 200 && row.reload.amount_cents == 200_000 && DiscourseSvdex::OfferingBid.where(user: people[0]).count == 2, "bids for separate offerings remain independent")
    [ {amount: "0"}, {amount: "-1"}, {amount: "1.001"}, {amount: "1e6"}, {amount: "99999999999999"}, {currency: "EUR"}, {proposed_terms: "  "}, {proposed_terms: "a" * 2001}, {confirmation: "nonbinding"} ].each do |invalid|
      member.put path, params: {bid: body[:bid].merge(invalid)}, headers: headers
      check_bid!(member.response.status == 400 && row.reload.amount_cents == 200_000, "invalid #{invalid.keys.first} cannot change the saved bid")
    end
    topic.update!(closed: true)
    member.put path, params: body, headers: headers
    check_bid!(member.response.status == 403, "closed offerings cannot accept or update bids")
    member.delete path, headers: headers
    check_bid!(member.response.status == 200 && row.reload.withdrawn_at.present?, "an investor can withdraw a bid from a closed offering")
    topic.update!(closed: false)
    member.put path, params: body, headers: headers
    check_bid!(row.reload.active? && row.withdrawn_at.nil?, "resubmission explicitly reconfirms a withdrawn bid")
    row.update!(expires_at: 1.day.ago)
    member.get path, headers: headers
    check_bid!(member.response.parsed_body.dig("bid", "active") == false, "expired bids no longer appear current")
    topic.first_post.update!(hidden: true)
    member.put path, params: body, headers: headers
    check_bid!(member.response.status == 404, "hidden offering posts do not accept bids")
    topic.first_post.update!(hidden: false)
    group = Group.find_by!(name: SiteSetting.svdex_private_offerings_group_name)
    group.add(people[0])
    member.put "/listings/offering-bids/#{restricted.id}.json", params: body, headers: headers
    check_bid!(member.response.status == 200, "private bids are available after native category membership is granted")
    group.remove(people[0])
    member.get "/listings/offering-bids/#{restricted.id}.json", headers: headers
    check_bid!(member.response.status == 404, "losing category access also blocks bid details")
    SiteSetting.svdex_bids_enabled = false
    member.put path, params: body, headers: headers
    check_bid!(member.response.status == 404, "bidding must be explicitly enabled")
    member.delete "/listings/offering-bids/#{restricted.id}.json", headers: headers
    check_bid!(member.response.status == 200, "withdrawal remains possible after access loss and feature disablement")
    stranger.delete path, headers: stranger_headers
    check_bid!(stranger.response.status == 404 && row.reload.withdrawn_at.nil?, "another investor cannot withdraw someone else's bid")
    check_bid!(indication.reload.amount_cents == 456_789, "bid lifecycle never rewrites or pools general interest")
    raise ActiveRecord::Rollback
  end
ensure
  SiteSetting.svdex_bids_enabled, SiteSetting.svdex_bids_staff_preview = before
end
puts "Offering bid checks complete; all test records rolled back."
