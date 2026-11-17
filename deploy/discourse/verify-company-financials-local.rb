# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def assert!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def login_for(user, password)
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: user.username, password: password }, headers: headers
  raise "Test login failed" unless app.response.status == 200
  [app, headers]
end

User.transaction do
  # Isolate this two-company scenario from optional directory fixtures. The
  # membership changes roll back along with the rest of this verification.
  company_group = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
  scenario_users = User.where(username: %w[svdex-company northstar]).select(:id)
  GroupUser.where(group_id: company_group.id, owner: false).where.not(user_id: scenario_users).delete_all
  password = SecureRandom.hex(24)
  create_user = ->(admin = false) {
    user = User.create!(username: "ccheck_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: 1, admin: admin)
    user.email_tokens.update_all(confirmed: true)
    user
  }
  actor = create_user.call(true)
  member = create_user.call
  staff, headers = login_for(actor, password)
  ordinary, ordinary_headers = login_for(member, password)
  svdex = User.find_by!(username: "svdex-company")
  northstar = User.find_by!(username: "northstar")
  path = "/listings/company-details/#{svdex.id}.json"
  ordinary.get path
  assert!(ordinary.response.status == 403, "ordinary members cannot read company editing controls")
  ordinary.put path, params: { company: { total_funding_usd: "1" } }, headers: ordinary_headers
  assert!(ordinary.response.status == 403, "ordinary members cannot change company financials")
  group = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
  group.add(member)
  ordinary.put "/listings/company-details/#{member.id}.json", params: { company: { total_funding_usd: "1" } }, headers: ordinary_headers
  assert!(ordinary.response.status == 403, "company membership does not grant financial editing rights")
  group.remove(member)
  staff.get path
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("sectors").any?, "staff can load company fields and native tag choices")
  staff.put path, params: { company: { total_funding_usd: "900000", last_valuation_usd: "20000000", stage: "Seed", headquarters_country: " United States " } }, headers: headers
  assert!(staff.response.status == 200, "staff can save numeric company financials and stage")
  assert!(svdex.reload.custom_fields["svdex_company_last_valuation_usd"] == 20_000_000, "valuation is stored as an actual number")
  assert!(svdex.custom_fields["svdex_company_stage"] == "Seed", "company stage persists independently of offering titles")
  assert!(svdex.custom_fields["svdex_company_headquarters_country"] == "United States", "staff headquarters country edits are normalized and persisted")
  northstar.custom_fields["svdex_company_total_funding_usd"] = 10_000_000
  northstar.custom_fields["svdex_company_last_valuation_usd"] = 9_000_000
  northstar.save_custom_fields
  endpoint = "/listings/company-directory.json"
  { { svdex_stage: "Seed" } => [svdex.id], { svdex_stage: "undisclosed" } => [northstar.id], { svdex_location: "United States" } => [svdex.id], { svdex_location: "undisclosed" } => [northstar.id], { svdex_stage: "Seed", svdex_location: "United States", svdex_funding: "under_1m" } => [svdex.id] }.each do |filters, ids|
    staff.get endpoint, params: filters
    body = staff.response.parsed_body
    assert!(staff.response.status == 200 && body.fetch("directory_items").map { |r| r.fetch("id") }.sort == ids.sort && body.dig("meta", "total_rows_directory_items") == ids.size, "stage and location filters match saved company facts: #{filters}")
    assert!(body.dig("meta", "locations").include?("United States") && body.dig("meta", "stages").include?("Seed"), "filter choices remain available across narrowed results")
  end
  [{ svdex_stage: "bogus" }, { svdex_open: "bogus" }, { svdex_location: "<b>US</b>" }].each do |filters|
    staff.get endpoint, params: filters
    assert!(staff.response.status == 400, "invalid stage, location and offering filters are rejected")
  end
  ordinary.get endpoint
  unless member.guardian.can_see_profile?(svdex)
    assert!(!ordinary.response.parsed_body.dig("meta", "locations").include?("United States"), "location options do not disclose hidden profile facts")
  end
  original_tag = northstar.custom_fields["svdex_company_tag_id"]
  northstar.custom_fields["svdex_company_tag_id"] = nil
  northstar.save_custom_fields
  staff.get endpoint, params: { svdex_open: "undisclosed" }
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") } == [northstar.id], "undisclosed open-offering filter distinguishes unlinked companies from No")
  northstar.custom_fields["svdex_company_tag_id"] = original_tag
  northstar.save_custom_fields
  funds = Group.find_by!(name: SiteSetting.svdex_funds_group_name)
  staff.get endpoint, params: { kind: "funds" }
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").empty?, "fund directory is empty before funds are classified")
  funds.add(northstar)
  { "all" => [svdex.id, northstar.id], "companies" => [svdex.id], "funds" => [northstar.id] }.each do |kind, ids|
    staff.get endpoint, params: { kind: kind, limit: 1 }
    body = staff.response.parsed_body
    assert!(staff.response.status == 200 && body.fetch("meta").fetch("total_rows_directory_items") == ids.size, "#{kind} classification is counted before pagination")
    staff.get endpoint, params: { kind: kind, svdex_funding: "10m_100m" }
    expected = ids.include?(northstar.id) ? [northstar.id] : []
    assert!(staff.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") } == expected, "#{kind} combines with financial filters")
  end
  staff.get endpoint, params: { kind: "funds", limit: 1 }
  assert!(staff.response.parsed_body.dig("meta", "load_more_directory_items").include?("kind=funds"), "pagination preserves listing type")
  funds.remove(northstar)
  staff.get endpoint, params: { kind: "bogus" }
  assert!(staff.response.status == 400, "unknown listing types are rejected")
  [["under_1m", [svdex.id]], ["1m_10m", []], ["10m_100m", [northstar.id]], ["over_1b", []]].each do |range, ids|
    staff.get endpoint, params: { svdex_funding: range }
    assert!(staff.response.status == 200, "company range endpoint succeeds for #{range}")
    body = staff.response.parsed_body
    assert!(body.fetch("directory_items").map { |r| r.fetch("id") }.sort == ids.sort, "#{range} uses inclusive lower and exclusive upper funding boundaries")
    assert!(body.fetch("meta").fetch("total_rows_directory_items") == ids.size, "filtered company count matches returned companies")
  end
  staff.get endpoint, params: { svdex_funding: "under_1m", svdex_valuation: "10m_100m", name: "svdex" }
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") } == [svdex.id], "company search and monetary filters combine")
  staff.get endpoint, params: { svdex_sector: svdex.custom_fields["svdex_company_sector_tag_id"], svdex_funding: "under_1m" }
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") } == [svdex.id], "sector and funding filters combine before pagination")
  staff.get endpoint, params: { svdex_funding: "bogus" }
  assert!(staff.response.status == 400, "invalid funding ranges are rejected")
  staff.get endpoint, params: { svdex_sector: -1 }
  assert!(staff.response.status == 400, "unknown sector filters are rejected")
  staff.get endpoint, params: { limit: 1 }
  first_page = staff.response.parsed_body
  staff.get first_page.fetch("meta").fetch("load_more_directory_items")
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").first.fetch("id") != first_page.fetch("directory_items").first.fetch("id"), "company pagination keeps native directory serialization")
  staff.get "/listings/company-profile/#{svdex.username}.json"
  assert!(staff.response.status == 200, "company profile facts can be loaded by authorized visitors")
  profile = staff.response.parsed_body
  assert!(profile.fetch("company").fetch("total_funding_usd") == 900_000, "profile Summary uses staff-maintained company facts")
  assert!(profile.fetch("offerings").any? && profile.fetch("offerings").all? { |t| topic = Topic.find(t.fetch("id")); DiscourseSvdex.offering_category_ids.include?(topic.category_id) && actor.guardian.can_see?(topic) }, "company Summary links visible offerings")
  staff.get "/listings/company-profile/#{member.username}.json"
  assert!(staff.response.status == 404, "ordinary profiles cannot load company Summary")
  guest = ActionDispatch::Integration::Session.new(Rails.application)
  guest.host! "localhost"
  directory = staff
  [["svdex_total_funding", false, northstar.id], ["svdex_total_funding", true, svdex.id], ["svdex_last_valuation", false, svdex.id], ["svdex_last_valuation", true, northstar.id]].each do |order, asc, expected|
    params = { period: "weekly", group: group.name, order: order }
    params[:asc] = "true" if asc
    directory.get "/listings/company-directory.json", params: params
    assert!(directory.response.status == 200, "company numeric directory query succeeds")
    rows = directory.response.parsed_body.fetch("directory_items")
    assert!(rows.first.fetch("user").fetch("id") == expected, "#{order} sorts #{asc ? 'ascending' : 'descending'} numerically")
    rows.each do |row|
      company = row.fetch("user").fetch("svdex_company")
      assert!(company["headquarters_country"] == "United States", "company country is included in the directory") if row["id"] == svdex.id
      tag_id = User.find(row.fetch("id")).custom_fields["svdex_company_tag_id"]
      expected_count = DiscourseSvdex::CompanyDirectory.offering_scope(actor.guardian).joins(:tags).where(tags: { id: tag_id }).distinct.count
      assert!(company["offerings"] == expected_count, "offering count follows linked tags and native visibility")
    end
  end
  names = [svdex.name, northstar.name]
  svdex.update!(name: "Aster Labs")
  northstar.update!(name: "Zeta Labs")
  [[true, svdex.id], [false, northstar.id]].each do |asc, first_id|
    params = { period: "all", group: group.name, order: "username" }
    params[:asc] = "true" if asc
    directory.get "/listings/company-directory.json", params: params
    assert!(directory.response.parsed_body.fetch("directory_items").first.fetch("id") == first_id, "company-name sorting follows displayed names, not account handles")
  end
  svdex.update!(name: names.first)
  northstar.update!(name: names.last)
  # Open means an accessible, listed offering topic that is neither closed nor archived.
  linked_ids = DiscourseSvdex::CompanyDirectory.offering_scope(actor.guardian).joins(:tags).where(tags: { id: svdex.custom_fields["svdex_company_tag_id"] }).pluck(:id)
  raise "Expected linked offering fixtures" if linked_ids.empty?
  Topic.where(id: linked_ids).update_all(closed: true)
  hidden_post = PostCreator.create!(actor, title: "Unlisted financing #{SecureRandom.hex(4)}", raw: "Private layout verification content.", category: SiteSetting.svdex_listings_category_id, tags: ["svdex", "finance"], skip_validations: true, skip_jobs: true)
  hidden_post.topic.update!(visible: false)
  directory.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name }
  facts = directory.response.parsed_body.fetch("directory_items").find { |row| row["id"] == svdex.id }.fetch("user").fetch("svdex_company")
  assert!(facts["open_offering"] == false, "closed offerings and an unlisted open topic do not mark a company open")
  staff.get endpoint, params: { svdex_open: "no" }
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") }.include?(svdex.id), "No open offering includes companies with only closed or unlisted offerings")
  staff.get endpoint, params: { svdex_open: "yes" }
  assert!(!staff.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") }.include?(svdex.id), "Yes open offering excludes unlisted topics")

  assert!(facts["offerings"] == linked_ids.length, "closed offerings remain in the total count while unlisted topics stay excluded")
  Topic.where(id: linked_ids).update_all(closed: false, archived: true)
  directory.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name }
  facts = directory.response.parsed_body.fetch("directory_items").find { |row| row["id"] == svdex.id }.fetch("user").fetch("svdex_company")
  assert!(facts["open_offering"] == false, "archived offerings do not mark a company open")
  Topic.where(id: linked_ids.first).update_all(archived: false)
  directory.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name }
  facts = directory.response.parsed_body.fetch("directory_items").find { |row| row["id"] == svdex.id }.fetch("user").fetch("svdex_company")
  assert!(facts["open_offering"] == true, "one listed open offering marks its company open")
  staff.get endpoint, params: { svdex_open: "yes", svdex_stage: "Seed", limit: 1 }
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") } == [svdex.id] && staff.response.parsed_body.dig("meta", "load_more_directory_items").include?("svdex_open=yes"), "open-offering filter combines with stage and persists in pagination")

  profile_location = svdex.user_profile.location
  staff.put path, params: { company: { headquarters_country: "" } }, headers: headers
  assert!(staff.response.status == 200 && svdex.reload.custom_fields["svdex_company_headquarters_country"].nil?, "staff can clear an undisclosed headquarters country")
  assert!(svdex.user_profile.reload.location == profile_location, "company country editing preserves native profile location")
  before = svdex.reload.custom_fields["svdex_company_last_valuation_usd"]
  [{ last_valuation_usd: "-1" }, { last_valuation_usd: "10M" }, { last_valuation_usd: "9007199254740992" }, { total_funding_usd: "1.5" }, { stage: "Made up" }, { headquarters_country: "x" * 81 }, { headquarters_country: "<b>US</b>" }, { headquarters_country: 123 }, { sector_tag_id: Tag.find_by!(name: "svdex").id }, { company_tag_id: northstar.custom_fields["svdex_company_tag_id"] }].each do |fields|
    staff.put path, params: { company: fields }, headers: headers
    assert!([400, 422].include?(staff.response.status), "invalid company field is rejected")
  end
  assert!(svdex.reload.custom_fields["svdex_company_last_valuation_usd"] == before, "rejected edits do not alter saved data")
  staff.put path, params: { company: { last_valuation_usd: "" } }, headers: headers
  assert!(staff.response.status == 200 && svdex.reload.custom_fields["svdex_company_last_valuation_usd"].nil?, "staff can clear an undisclosed valuation")
  staff.get endpoint, params: { svdex_valuation: "undisclosed" }
  assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") } == [svdex.id], "undisclosed valuation includes missing facts only")
  %w[true false].each do |asc|
    params = { period: "all", group: group.name, order: "svdex_last_valuation" }
    params[:asc] = "true" if asc == "true"
    directory.get "/listings/company-directory.json", params: params
    assert!(directory.response.parsed_body.fetch("directory_items").last.fetch("id") == svdex.id, "missing valuations sort last in either direction")
  end
  guest.get endpoint, params: { svdex_funding: "under_1m" }
  assert!(guest.response.status == 200 && guest.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") } == [svdex.id], "guests can filter public company facts without a trust-level exemption")
  guest.get "/listings/company-profile/#{svdex.username}.json"
  assert!(guest.response.status == 200 && guest.response.parsed_body.dig("company", "total_funding_usd") == 900_000, "guests can view the current company Summary")
  assert!(!Guardian.new(nil).can_see_profile?(member), "ordinary new-user profile privacy is unchanged")
  assert!(DiscourseSvdex::CompanyDirectory::STAGES.include?("Non-venture") && !DiscourseSvdex::CompanyDirectory::STAGES.include?("Bootstrapped"), "stage vocabulary uses Non-venture")
  original_hide = svdex.user_option.hide_profile
  original_allow_hide = SiteSetting.allow_users_to_hide_profile
  SiteSetting.allow_users_to_hide_profile = true
  svdex.user_option.update!(hide_profile: true)
  guest.get endpoint, params: { svdex_funding: "under_1m" }
  assert!(!guest.response.parsed_body.fetch("directory_items").map { |r| r.fetch("id") }.include?(svdex.id), "explicitly hidden company facts cannot be inferred through filters")
  guest.get "/listings/company-profile/#{svdex.username}.json"
  assert!([403, 404].include?(guest.response.status), "explicit company profile privacy remains respected")
  svdex.user_option.update!(hide_profile: original_hide)
  SiteSetting.allow_users_to_hide_profile = original_allow_hide
  previous_visibility = group.visibility_level
  group.update!(visibility_level: Group.visibility_levels[:staff])
  ordinary.get "/listings/company-directory.json"
  assert!(ordinary.response.status == 403, "custom company directory protects private group membership")
  ordinary.get "/listings/company-profile/#{svdex.username}.json"
  assert!([403, 404].include?(ordinary.response.status), "company Summary protects private group membership")
  group.update!(visibility_level: previous_visibility)
  guest.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name }
  guest.response.parsed_body.fetch("directory_items").each do |row|
    target = User.find(row.fetch("id"))
    if !Guardian.new(nil).can_see_profile?(target)
      assert!(!row.fetch("user").key?("svdex_company"), "company financials respect native profile visibility")
    end
  end
  guest.get "/listings/company-directory.json", params: { kind: "all", period: "all", group: group.name, name: "Northstar Instruments" }
  assert!(guest.response.parsed_body.fetch("directory_items").map { |row| row.fetch("id") } == [northstar.id], "directory search matches actual company names")
  guest.get "/directory_items.json", params: { period: "all", order: "likes_given" }
  assert!(guest.response.status == 200 && guest.response.parsed_body.fetch("directory_items").all? { |row| row.key?("likes_given") }, "ordinary Users directory retains its native activity columns")
  staff.get "/listings/company-details/#{member.id}.json"
  assert!(staff.response.status == 404, "company editor is unavailable for ordinary accounts")
  raise ActiveRecord::Rollback
end
