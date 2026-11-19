# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
DiscourseSvdex::Prototypes::CompanyProfiles.setup!

def capacity_assert!(value, message)
  raise message unless value
  puts "PASS #{message}"
end
def capacity_session(user = nil, password = nil)
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
before = [SiteSetting.svdex_interest_enabled, SiteSetting.svdex_interest_public_totals, SiteSetting.svdex_interest_staff_preview, SiteSetting.svdex_private_access_contact]
begin
  SiteSetting.svdex_interest_enabled = SiteSetting.svdex_interest_public_totals = true
  SiteSetting.svdex_interest_staff_preview = false
  User.transaction do
    password = SecureRandom.hex(24)
    staff = User.create!(username: "vstaff_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, admin: true)
    member = User.create!(username: "vmember_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: 0)
    other = User.create!(username: "vother_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true)
    [staff, member, other].each { |u| u.email_tokens.update_all(confirmed: true) }
    SiteSetting.svdex_private_access_contact = staff.username
    guest, = capacity_session
    account, headers = capacity_session(member, password)
    outsider, other_headers = capacity_session(other, password)
    admin, staff_headers = capacity_session(staff, password)
    org = User.find_by!(username: "svdex-company")
    fund = User.find_by!(username: "svdex-fund-i")
    DiscourseSvdex::InterestIndication.where(organization_id: [org.id, fund.id]).delete_all
    endpoint = "/listings/interest-verifications/users/#{member.id}.json"
    review = { side: "buy", amount: "200000.00", checked_on: Date.current.to_s, expires_on: (Date.current + 30).to_s, evidence_reference: "Private verifier reference SECURE-RECEIPT-200" }
    [guest, account, outsider].each do |viewer|
      viewer.get endpoint
      capacity_assert!(viewer.response.status == 403, "capacity evidence and staff history are unavailable outside staff")
    end
    account.post endpoint, params: { verification: review }, headers: headers
    capacity_assert!(account.response.status == 403, "members cannot verify their own funds")
    path = "/listings/interests/#{org.id}"
    body = { interest: { amount: "200000.01", currency: "USD", market: "either", confirmation: "nonbinding-public-v1" } }
    account.put "#{path}/buy.json", params: body, headers: headers
    row = DiscourseSvdex::InterestIndication.find_by!(user: member, organization: org, side: "buy")
    capacity_assert!(account.response.status == 200 && row.amount_cents == 20_000_001 && account.response.parsed_body.dig("interest", "verification", "state") == "unverified", "unverified interest saves privately with exact cents")
    totals = ->(target = org) { DiscourseSvdex::InterestIndication.totals([target.id], Guardian.new)[target.id] || {} }
    capacity_assert!(totals.call.empty?, "consent alone never publishes unverified amounts")
    request_path = "/listings/interest-verifications/requests/#{row.id}.json"
    outsider.post request_path, headers: other_headers
    capacity_assert!(outsider.response.status == 404, "another member cannot request review of someone else's indication")
    account.post request_path, headers: headers
    capacity_assert!(account.response.status == 200, "a new member can request staff verification through native private intake")
    request_topic = Topic.find_by!(title: "Interest verification: #{org.name}", user_id: member.id)
    capacity_assert!(request_topic.archetype == Archetype.private_message && request_topic.topic_allowed_users.pluck(:user_id).sort == [member.id, staff.id].sort, "verification requests are private to the submitter and staff reviewer")
    admin.post endpoint, params: { verification: review }, headers: staff_headers
    capacity_assert!(admin.response.status == 200, "staff can record an exact private buying-capacity amount")
    first_review = DiscourseSvdex::InterestVerification.where(user: member, side: "buy", superseded_at: nil).first!
    capacity_assert!(first_review.amount_cents == 20_000_000 && first_review.reviewer_id == staff.id && first_review.checked_on == Date.current, "capacity records preserve amount, reviewer and check date")
    capacity_assert!(totals.call.empty? && DiscourseSvdex::InterestVerification.qualification(row)[:state] == "above_limit", "one cent above reviewed capacity excludes the whole indication, without clipping")
    body[:interest][:amount] = "200000.00"
    account.put "#{path}/buy.json", params: body, headers: headers
    capacity_assert!(totals.call["buy"] == 20_000_000, "a covered consented indication contributes to public totals")
    account.put "/listings/interests/#{fund.id}/buy.json", params: body, headers: headers
    capacity_assert!(totals.call(fund)["buy"] == 20_000_000 && totals.call["buy"] == 20_000_000, "the same buying capacity can support alternative company/fund interests without being treated as reserved cash")
    guest.get "/listings/company-profile/#{org.username}.json"
    capacity_assert!(!guest.response.body.include?(review[:evidence_reference]) && !guest.response.body.include?(member.username) && !guest.response.body.include?("checked_on"), "public aggregates expose no verification evidence, dates, identity or private capacity record")
    account.get "#{path}.json", headers: headers
    owner_data = account.response.parsed_body
    capacity_assert!(owner_data.dig("capacity", "buy", "amount_cents") == 20_000_000 && !account.response.body.include?(review[:evidence_reference]), "the owner can see their private reviewed amount without exposing evidence references")
    [review.merge(amount: "-1"), review.merge(evidence_reference: ""), review.merge(checked_on: (Date.current + 1).to_s), review.merge(expires_on: (Date.current + 400).to_s)].each do |bad|
      admin.post endpoint, params: { verification: bad }, headers: staff_headers
      capacity_assert!(admin.response.status == 400 && first_review.reload.superseded_at.nil?, "invalid reviews cannot replace a valid current capacity")
    end
    seller = review.merge(side: "sell", amount: "50000.00", target_type: "account", target_id: fund.id, holding_details: "Fund interest and authority reviewed privately")
    account.put "#{path}/sell.json", params: { interest: body[:interest].merge(amount: "50000.00", market: "secondary") }, headers: headers
    capacity_assert!(totals.call["sell"].nil?, "buying capacity never verifies a sell holding")
    admin.post endpoint, params: { verification: seller }, headers: staff_headers
    capacity_assert!(admin.response.status == 200 && totals.call["sell"].nil?, "sell verification for one fund cannot substantiate another company's holding")
    seller[:target_id] = org.id
    admin.post endpoint, params: { verification: seller }, headers: staff_headers
    capacity_assert!(admin.response.status == 200 && totals.call["sell"] == 5_000_000, "a reviewed company-specific holding covers that sell indication")
    profile = DiscourseSvdex::Prototypes::CompanyProfileRecord.find_by(id: org.id) || DiscourseSvdex::Prototypes::CompanyProfileRecord.create!(id: org.id, slug: "capacity-#{SecureRandom.hex(4)}", name: "Harbor Instruments", summary: "Optical research infrastructure.")
    profile.update!(listed: true)
    DiscourseSvdex::InterestIndication.where(company_profile_id: profile.id).delete_all
    account.put "/company-profile-interests/#{profile.id}/sell.json", params: { interest: body[:interest].merge(amount: "50000.00", market: "secondary") }, headers: headers
    profile_totals = -> { DiscourseSvdex::Prototypes::CompanyRelationships.totals([profile.id], Guardian.new)[profile.id] || {} }
    capacity_assert!(profile_totals.call["sell"].nil?, "identical numeric account and company IDs cannot share a sell verification")
    admin.post endpoint, params: { verification: seller.merge(target_type: "company", target_id: profile.id) }, headers: staff_headers
    capacity_assert!(admin.response.status == 200 && profile_totals.call["sell"] == 5_000_000, "independent company holdings use their own typed verification scope")
    profile_review = DiscourseSvdex::InterestVerification.where(user: member, side: "sell", target_type: "company", target_id: profile.id, superseded_at: nil).first!
    account.delete "/listings/interest-verifications/#{profile_review.id}.json", headers: headers
    capacity_assert!(account.response.status == 403, "members cannot revoke or edit staff verification records")
    admin.delete "/listings/interest-verifications/#{profile_review.id}.json", headers: staff_headers
    capacity_assert!(admin.response.status == 200 && profile_totals.call.empty? && totals.call["sell"] == 5_000_000, "revocation immediately removes only the matching reviewed public amount")
    DiscourseSvdex::InterestVerification.where(id: first_review.id).update_all(checked_on: Date.current - 30, expires_on: Date.current - 1)
    capacity_assert!(totals.call["buy"].nil? && DiscourseSvdex::InterestVerification.qualification(row.reload)[:state] == "expired", "expiry removes capacity from public aggregates automatically")
    admin.post endpoint, params: { verification: review.merge(amount: "300000.00") }, headers: staff_headers
    capacity_assert!(totals.call["buy"] == 20_000_000, "a new review restores covered amounts")
    admin.post endpoint, params: { verification: review.merge(amount: "100000.00") }, headers: staff_headers
    lower = DiscourseSvdex::InterestVerification.where(user: member, side: "buy", superseded_at: nil).first!
    capacity_assert!(totals.call["buy"].nil?, "a lower replacement capacity immediately excludes larger indications")
    admin.delete "/listings/interest-verifications/#{lower.id}.json", headers: staff_headers
    capacity_assert!(totals.call["buy"].nil?, "revoking a replacement never revives an older higher capacity")
    admin.get endpoint, headers: staff_headers
    capacity_assert!(admin.response.headers["Cache-Control"] == "private, no-store" && admin.response.parsed_body["records"].length >= 6, "private review history retains replacements, revocations and evidence for staff")
    raise ActiveRecord::Rollback
  end
ensure
  SiteSetting.svdex_interest_enabled, SiteSetting.svdex_interest_public_totals, SiteSetting.svdex_interest_staff_preview, SiteSetting.svdex_private_access_contact = before
end
puts "Interest verification checks complete; financial reviews and request messages rolled back."
