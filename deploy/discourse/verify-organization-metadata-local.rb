# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def assert!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

original_hide = SiteSetting.allow_users_to_hide_profile
User.transaction do
  directory = DiscourseSvdex::CompanyDirectory
  owner = User.find_by!(username: "svdex")
  company = User.find_by!(username: "svdex-company")
  guest = Guardian.new
  fields = directory::FIELDS
  people = [{"name" => "Research contact", "role" => "Director", "url" => "https://example.org/person"}]
  people = directory.validate!("key_people", people)
  company.custom_fields[fields.fetch("key_people")] = people
  company.custom_fields[fields.fetch("entity_type")] = "spv"
  company.custom_fields[fields.fetch("related_entities")] = [{"name" => "Underlying asset", "role" => "Underlying", "url" => "https://example.org/asset"}]
  company.custom_fields[fields.fetch("last_valuation_usd")] = nil
  company.save_custom_fields
  company.reload
  assert!(company.custom_fields[fields.fetch("key_people")] == people, "structured people survive custom-field storage")
  directory.populate([company], guest)
  details = company.svdex_company_directory_details
  assert!(details[:entity_type] == "spv" && details[:last_valuation_usd].nil?, "SPV metadata does not inherit or invent an underlying valuation")
  assert!(details[:key_people].first["url"] == "https://example.org/person", "people without accounts retain their professional links")
  assert!(details[:open_offerings].is_a?(Integer) && details[:open_offerings] >= 0, "open offering counts are nonnegative numbers")
  assert!(details[:open_offerings_url].include?("svdex_active=1"), "open offering links carry the active filter")
  [ ["aum_usd", "not-a-number"], ["aum_usd", -1], ["manager_url", "javascript:alert(1)"], ["key_people", [{"name" => "A", "role" => "B", "user_id" => "unknown"}]], ["facts_as_of", "2026-02-31"], ["vintage_year", "2030xyz"], ["entity_type", "invented"] ].each do |key, value|
    begin
      directory.validate!(key, value)
      raise "Accepted invalid #{key}"
    rescue Discourse::InvalidParameters
      puts "PASS rejects invalid #{key}"
    end
  end
  hidden = User.create!(username: "private_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 1)
  hidden.user_option.update!(hide_profile: true)
  SiteSetting.allow_users_to_hide_profile = true
  references = directory.public_references([{"name" => "A contact", "role" => "Director", "user_id" => hidden.id}], guest)
  assert!(!references.first.key?("url") && !references.first.key?("user_id"), "private associated accounts never leak through person links")
  fund = Group.find_by!(name: SiteSetting.svdex_funds_group_name)
  fund.add(company)
  company.custom_fields[fields.fetch("fund_size_usd")] = 50_000_000
  company.custom_fields[fields.fetch("fund_size_basis")] = "target"
  company.custom_fields[fields.fetch("vintage_year")] = 2024
  company.custom_fields[fields.fetch("fund_life")] = nil
  company.save_custom_fields
  directory.populate([company], owner.guardian)
  facts = company.svdex_company_directory_details
  assert!(facts[:kind] == "funds" && facts[:fund_size_basis] == "target", "fund vehicles disclose the basis of fund size")
  assert!(facts[:aum_usd].nil?, "a fundraising target never becomes AUM implicitly")
  company.custom_fields[fields.fetch("aum_usd")] = directory.validate!("aum_usd", 500_000)
  company.save_custom_fields
  directory.populate([company], guest)
  assert!(company.svdex_company_directory_details[:aum_usd] == 500_000 && company.svdex_company_directory_details[:fund_size_usd] == 50_000_000, "AUM and fundraising size remain separate public disclosures")
  items = DirectoryItem.where(period_type: DirectoryItem.period_types[:all])
  assert!(directory.filter_items(items, directory.validate_filters!("svdex_aum" => "under_1m"), guest).where(user_id: company.id).exists?, "AUM ranges use managed assets rather than fundraising target")
  aum_app = ActionDispatch::Integration::Session.new(Rails.application)
  aum_app.host! "localhost"
  aum_app.get "/listings/company-directory.json", params: { kind: "funds", order: "svdex_aum", asc: true, limit: 1 }
  assert!(aum_app.response.status == 200 && aum_app.response.parsed_body.fetch("directory_items").first.dig("user", "id") == company.id, "guest AUM sorting applies before pagination")
  assert!(facts[:vintage_year] == 2024 && facts[:fund_life].nil?, "vintage never creates an inferred maturity")
  all = DirectoryItem.where(period_type: DirectoryItem.period_types[:all])
  filters = directory.validate_filters!("svdex_type" => "spv")
  assert!(directory.filter_items(all, filters, owner.guardian).where(user_id: company.id).exists?, "SPV filtering is independent of sector")
  # Active counts exclude both archived and closed topics, including for staff.
  tag = company.custom_fields[fields.fetch("company_tag_id")]
  topics = directory.offering_scope(owner.guardian).joins(:tags).where(tags: {id:tag})
  assert!(topics.exists?, "local linked offerings exist for count verification")
  topics.update_all(closed: true)
  directory.populate([company], owner.guardian)
  assert!(company.svdex_company_directory_details[:open_offerings] == 0, "closed offerings contribute zero to active counts")
  topics.update_all(closed: false, archived: true)
  directory.populate([company], owner.guardian)
  assert!(company.svdex_company_directory_details[:open_offerings] == 0, "archived offerings contribute zero to active counts")
  query = TopicQuery.new(owner, category: SiteSetting.svdex_listings_category_id, tags: ["svdex"], svdex_active: "1")
  assert!(query.list_latest.topics.none? { |topic| topic.closed || topic.archived }, "active offering destination excludes closed and archived topics")
  visitor = ActionDispatch::Integration::Session.new(Rails.application)
  visitor.host! "localhost"
  destination = company.svdex_company_directory_details.fetch(:open_offerings_url).split("?").first + "/l/latest.json"
  visitor.get destination, params: {svdex_active:"1"}
  assert!(visitor.response.status == 200 && visitor.response.parsed_body.fetch("topic_list").fetch("topics").empty?, "active count destination applies its filter through the native tag HTTP route")
  topics.where(id:topics.first.id).update_all(archived:false)
  visitor.get destination, params: {svdex_active:"1"}
  assert!(visitor.response.status == 200 && visitor.response.parsed_body.fetch("topic_list").fetch("topics").length == 1, "active count destination shows precisely the accessible open offering")
  # Exercise JSON writes, clearing arrays, and access control through the API.
  password = SecureRandom.hex(24)
  admin = User.create!(username:"orgadmin_#{SecureRandom.hex(4)}", email:"#{SecureRandom.hex(8)}@example.invalid", password:password, admin:true, active:true, approved:true)
  admin.email_tokens.update_all(confirmed:true)
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.get "/session/csrf.json"
  headers = {"X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest"}
  app.post "/session.json", params:{login:admin.username,password:password},headers:headers
  assert!(app.response.status == 200, "staff API test session works")
  path = "/listings/company-details/#{company.id}.json"
  json_headers = headers.merge("CONTENT_TYPE" => "application/json")
  app.put path, params: {company:{key_people:people, aum_usd:250_000, fund_size_usd:123, fund_size_basis:"commitments"}}.to_json, headers:json_headers
  assert!(app.response.status == 200 && app.response.parsed_body.dig("company", "key_people").length == 1 && app.response.parsed_body.dig("company", "aum_usd") == 250_000, "staff can save structured disclosures through the native admin endpoint")
  app.put path, params: {company:{key_people:[]}}.to_json, headers:json_headers
  assert!(app.response.status == 200 && app.response.parsed_body.dig("company", "key_people") == [], "staff can clear all people without retaining stale associations")
  app.put path, params: {company:{fund_size_basis:nil}}.to_json, headers:json_headers
  assert!(app.response.status == 400, "fund size cannot lose its target/raised/commitments basis")
  raise ActiveRecord::Rollback
end

SiteSetting.allow_users_to_hide_profile = original_hide
