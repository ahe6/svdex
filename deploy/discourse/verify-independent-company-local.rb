# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
DiscourseSvdex::Prototypes::CompanyProfiles.setup!
def profile_assert!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end
def profile_session(user = nil, password = nil)
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
User.transaction do
  password = SecureRandom.hex(24)
  staff = User.create!(username: "padmin_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, admin: true)
  member = User.create!(username: "pmember_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: 2)
  [staff, member].each { |u| u.email_tokens.update_all(confirmed: true) }
  count = User.count
  record = DiscourseSvdex::Prototypes::CompanyProfileRecord.create!(slug: "harbor-#{SecureRandom.hex(4)}", name: "Harbor Research", summary: "Research infrastructure for private markets.", facts: { total_funding_usd: 2_000_000, company_tag_id: User.find_by!(username: "svdex-company").custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch("company_tag_id")] })
  profile_assert!(User.count == count && record.official_account_id.nil?, "a company profile exists without creating or requiring an account")
  guest, = profile_session
  path = "/company-profiles/#{record.slug}.json"
  guest.get path
  profile_assert!(guest.response.status == 404, "unlisted company profiles remain unavailable to guests")
  source_logo = User.find_by!(username: "svdex-company").uploaded_avatar_id || Upload.first!.id
  record.update!(logo_upload_id: source_logo)
  profile_assert!(UploadReference.exists?(target: record, upload_id: source_logo), "company logos retain their own native upload reference without an official account")
  record.update!(listed: true)
  guest.get path
  profile_assert!(guest.response.status == 200 && guest.response.parsed_body.dig("company", "total_funding_usd") == 2_000_000 && !guest.response.parsed_body.key?("account") && !guest.response.parsed_body.key?("editor") && (guest.response.parsed_body.fetch("company").keys & %w[sector_tag_id company_tag_id]).empty?, "published independent facts are public without a fabricated user")
  profile_assert!(guest.response.parsed_body.dig("profile", "logo_template") == Upload.find(source_logo).url, "independent profile payload preserves the original uploaded company logo")
  guest.put path, params: { profile: { name: "Changed" } }
  profile_assert!(guest.response.status == 403 && record.reload.name == "Harbor Research", "guests cannot edit independent facts")
  signed_in, member_headers = profile_session(member, password)
  signed_in.put path, params: { profile: { name: "Changed" } }, headers: member_headers
  profile_assert!(signed_in.response.status == 403, "ordinary accounts cannot claim or edit a company by choosing its slug")
  editor, headers = profile_session(staff, password)
  account = User.find_by!(username: "svdex-company")
  original_funding = account.custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch("total_funding_usd")]
  editor.put path, params: { profile: { official_username: account.username, facts: { total_funding_usd: 3_000_000 } } }, headers: headers
  profile_assert!(editor.response.status == 200 && record.reload.official_account_id == account.id && record.facts["total_funding_usd"] == 3_000_000, "staff can maintain independent facts and explicitly link a participation account")
  profile_assert!(account.reload.custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch("total_funding_usd")] == original_funding, "editing independent company facts never rewrites account facts")
  editor.put path, params: { profile: { facts: { total_funding_usd: "bad" } } }, headers: headers
  profile_assert!(editor.response.status == 400 && record.reload.facts["total_funding_usd"] == 3_000_000, "financial validation is reused without losing saved facts")
  original_hide = SiteSetting.allow_users_to_hide_profile
  begin
    SiteSetting.allow_users_to_hide_profile = true
    account.user_option.update!(hide_profile: true)
    guest.get path
    profile_assert!(guest.response.status == 200 && !guest.response.parsed_body.key?("account") && !guest.response.parsed_body.key?("interest_account"), "a private linked account is redacted without making independently published company facts private")
  ensure
    SiteSetting.allow_users_to_hide_profile = original_hide
    account.user_option.update!(hide_profile: false)
  end
  editor.put path, params: { profile: { official_username: "" } }, headers: headers
  profile_assert!(editor.response.status == 200 && record.reload.official_account_id.nil? && User.exists?(account.id), "unlinking an account preserves both the company profile and the account")
  profile_assert!(User.count == count, "profile maintenance creates no login identities")
  original_enabled, original_public = SiteSetting.svdex_interest_enabled, SiteSetting.svdex_interest_public_totals
  begin
    SiteSetting.svdex_interest_enabled = true
    SiteSetting.svdex_interest_public_totals = true
    DiscourseSvdex::InterestVerification.record!(member, actor: staff, side: "buy", amount: "1250.25", checked_on: Date.current.to_s, expires_on: (Date.current + 30).to_s, evidence_reference: "Transactional independent-profile fixture")
    endpoint = "/company-profile-interests/#{record.id}"
    input = { interest: { amount: "1250.25", currency: "USD", market: "either", confirmation: "nonbinding-public-v1" } }
    guest.put "#{endpoint}/buy.json", params: input
    profile_assert!(guest.response.status == 403, "independent company interest requires login")
    signed_in.put "#{endpoint}/buy.json", params: input, headers: member_headers
    profile_assert!(signed_in.response.status == 200, "a member can indicate interest with no official company account")
    row = DiscourseSvdex::InterestIndication.find_by!(company_profile_id: record.id, user: member, side: "buy")
    profile_assert!(row.organization_id.nil? && row.amount_cents == 125025 && row.aggregate_consent_at, "interest uses a company reference and exact cents with explicit aggregate consent")
    other = DiscourseSvdex::Prototypes::CompanyProfileRecord.create!(slug: "other-#{SecureRandom.hex(4)}", name: "Other Company", summary: "Independent infrastructure company.", listed: true)
    signed_in.put "/company-profile-interests/#{other.id}/buy.json", params: input, headers: member_headers
    profile_assert!(signed_in.response.status == 200, "one investor can record interest in two account-free companies without ID collisions")
    guest.get path
    profile_assert!(guest.response.parsed_body.dig("company", "interest_totals", "buy") == 125025, "consented current interest totals are visible to guests")
    signed_in.put "#{endpoint}/buy.json", params: { interest: input[:interest].merge(amount: "42.10", confirmation: "nonbinding") }, headers: member_headers
    profile_assert!(signed_in.response.status == 200 && row.reload.amount_cents == 4210 && row.aggregate_consent_at.nil?, "editing replaces one indication and can remove aggregate consent")
    guest.get path
    profile_assert!(guest.response.parsed_body.dig("company", "interest_totals", "buy").nil?, "non-consented amounts never enter public totals")
    signed_in.get "/listings/my-interest.json", headers: member_headers
    history = signed_in.response.parsed_body.fetch("records").find { |item| item["id"] == row.id && item["kind"] == "interest" }
    profile_assert!(history.dig("organization", "url") == "/company/#{record.slug}" && history.dig("organization", "interest_endpoint") == endpoint && history["can_edit"], "My Bids links and edits the independent company rather than an account with the same numeric ID")
    editor.get "#{endpoint}.json", headers: headers
    profile_assert!(editor.response.parsed_body.fetch("interest").empty?, "another account never receives the investor's own records as its own")
    signed_in.put "#{endpoint}/sell.json", params: input, headers: member_headers
    profile_assert!(signed_in.response.status == 400, "sell interest still requires secondary-market terms")
    signed_in.put "#{endpoint}/buy.json", params: { interest: input[:interest].merge(topic_id: 1) }, headers: member_headers
    profile_assert!(signed_in.response.status == 400, "company-wide interest cannot silently claim an offering reference")
    record.update!(listed: false)
    signed_in.get "#{endpoint}.json", headers: member_headers
    profile_assert!(signed_in.response.status == 404, "unpublished company interest endpoints are unavailable to ordinary members")
    signed_in.get "/listings/my-interest.json", headers: member_headers
    hidden = signed_in.response.parsed_body.fetch("records").find { |item| item["id"] == row.id && item["kind"] == "interest" }
    profile_assert!(hidden["organization"].nil? && !hidden["can_edit"], "owner history redacts an unpublished company but preserves the investor's amount")
    signed_in.delete "/listings/my-interest/interest/#{row.id}.json", headers: member_headers
    profile_assert!(signed_in.response.status == 200 && row.reload.withdrawn_at, "withdrawal still works after independent company publication is removed")
    record.update!(listed: true)
    directory = "/company-profiles.json"
    guest.get directory, params: { name: record.name }
    profile_assert!(guest.response.status == 200 && guest.response.parsed_body.fetch("profiles").map { |item| item.dig("profile", "id") } == [record.id], "directory search returns independently published profiles")
    guest.get directory, params: { name: record.name, svdex_funding: "1m_10m", order: "svdex_last_valuation" }
    profile_assert!(guest.response.status == 200 && guest.response.parsed_body["total"] == 1, "directory monetary filters use the independent facts")
    guest.get directory, params: { svdex_funding: "bad" }
    profile_assert!(guest.response.status == 400, "directory rejects unknown ranges")
    review = { discovery: { provenance: "discovered", contributor: member.username, listed_at: Time.current.iso8601(6), reason: "Reviewed company background and original source." } }
    credit_path = "/company-profiles/#{record.slug}/discovery.json"
    signed_in.put credit_path, params: review, headers: member_headers
    profile_assert!(signed_in.response.status == 403, "members cannot award themselves discovery credit")
    editor.put credit_path, params: review, headers: headers
    profile_assert!(editor.response.status == 200, "staff can review account-independent discovery credit")
    discovery = DiscourseSvdex::Discovery.find_by!(company_profile_id: record.id)
    profile_assert!(discovery.entity_user_id.nil? && discovery.original_entity_user_id.nil? && discovery.original_company_profile_id == record.id && DiscourseSvdex::DiscoveryEvent.exists?(discovery_id: discovery.id), "discovery attribution and audit snapshots reference the independent company")
    guest.get path
    profile_assert!(guest.response.parsed_body.dig("discovery", "contributor", "username") == member.username, "the company publicly credits its visible contributor")
    data = DiscourseSvdex::Discoveries.history(member, Guardian.new, limit: 1)
    profile_assert!(data[:count] == 1 && data[:records].first[:url] == "/company/#{record.slug}", "native contributor discovery history includes independent company profiles")
    editor.put credit_path, params: { discovery: review[:discovery].merge(listed_at: 1.day.ago.iso8601) }, headers: headers
    profile_assert!(editor.response.status == 400, "review cannot rewrite the original discovery timestamp")
    record.update!(listed: false)
    profile_assert!(DiscourseSvdex::Discoveries.history(member, Guardian.new)[:count] == 0, "unpublished independent profiles do not leak through discovery totals")
    guest.get directory, params: { name: record.name }
    profile_assert!(guest.response.parsed_body["total"] == 0, "unpublished profiles do not leak through directory totals")
    record.update!(listed: true)
  ensure
    SiteSetting.svdex_interest_enabled = original_enabled
    SiteSetting.svdex_interest_public_totals = original_public
  end

  temporary = User.create!(username: "plink_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true)
  record.update!(official_account: temporary)
  temporary.destroy!
  profile_assert!(record.reload.official_account_id.nil? && record.facts["total_funding_usd"] == 3_000_000, "native account deletion clears its optional link while preserving the independent company record")
  raise ActiveRecord::Rollback
end
puts "Independent company checks complete; scenario records rolled back."
