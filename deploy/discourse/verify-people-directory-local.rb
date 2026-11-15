# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
companies = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
funds = Group.find_by!(name: SiteSetting.svdex_funds_group_name)
org_ids = GroupUser.joins(:user).where(users: { admin: false, moderator: false }).where(group_id: [companies.id, funds.id]).distinct.pluck(:user_id)
raise "Organization fixtures missing" if org_ids.empty?
app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
%w[all weekly].each do |period|
  app.get "/directory_items.json", params: { period: period, order: "username", asc: true }
  raise "Users request failed" unless app.response.status == 200
  payload = app.response.parsed_body
  ids = payload.fetch("directory_items").map { |row| row.fetch("id") }
  raise "Organization leaked into Users" if (ids & org_ids).any?
  expected = DirectoryItem.where(period_type: DirectoryItem.period_types.fetch(period.to_sym)).where.not(user_id: org_ids).count
  raise "Users count includes organizations" unless payload.dig("meta", "total_rows_directory_items") == expected
end
org = User.find(org_ids.first)
app.get "/directory_items.json", params: { period: "all", username: org.username }
raise "Exact user search exposes an organization" unless app.response.parsed_body.fetch("directory_items").empty?
app.get "/directory_items.json", params: { period: "all", name: org.username }
raise "Name search exposes an organization" if app.response.parsed_body.fetch("directory_items").any? { |row| org_ids.include?(row.fetch("id")) }
User.transaction do
  fund = User.find_by!(username: "svdex-fund-i")
  GroupUser.where(group_id: companies.id, user_id: fund.id).destroy_all
  result = DirectoryItemsQuery.new(user: fund, guardian: Guardian.new(fund)).call(period_type: DirectoryItem.period_types[:all], prioritize_user: true)
  raise "Fund-only membership/current-user priority bypassed exclusion" if result.items.any? { |row| org_ids.include?(row.user_id) }
  raise ActiveRecord::Rollback
end
app.get "/directory_items.json", params: { period: "all", group: companies.name }
raise "Organization directory lost members" unless app.response.parsed_body.fetch("directory_items").map { |row| row.fetch("id") }.sort == companies.users.where(admin: false, moderator: false).pluck(:id).sort
app.get "/u/#{org.username}.json"
raise "Company profile became inaccessible" unless app.response.status == 200
puts "PASS Users hides companies/funds before counts, searches and pagination; fund-only and current-user exclusions hold; organization directory and profiles remain available"

User.transaction do
  person = User.find_by!(username: "maya-chen")
  person.update!(trust_level: 2)
  person.user_option.update!(hide_profile: false)
  organizations = companies.users.where(admin: false, moderator: false).order(:id).limit(2).to_a
  raise "Two public organization fixtures required" unless organizations.length == 2
  field = DiscourseSvdex::CompanyDirectory::FIELDS.fetch("key_people")
  organizations.each do |organization|
    organization.custom_fields[field] = [{ "name" => "Maya Chen", "user_id" => person.id }, { "name" => "Maya Chen", "user_id" => person.id }]
    organization.save_custom_fields
  end
  app.get "/directory_items.json", params: { period: "weekly", order: "svdex_organizations" }
  raise "Organization count query failed" unless app.response.status == 200
  rows = app.response.parsed_body.fetch("directory_items")
  member = rows.find { |row| row["id"] == person.id }
  raise "Guest count missing or duplicate links counted" unless member&.fetch("svdex_organizations") == 2
  raise "Count sort failed" unless rows.map { |row| row.fetch("svdex_organizations") } == rows.map { |row| row.fetch("svdex_organizations") }.sort.reverse
  app.get "/directory_items.json", params: { period: "all", order: "svdex_organizations", asc: true }
  raise "Ascending organization sort failed" unless app.response.status == 200 && app.response.parsed_body.fetch("directory_items").map { |row| row.fetch("svdex_organizations") }.then { |counts| counts == counts.sort }
  SiteSetting.allow_users_to_hide_profile = true
  organizations.last.user_option.update!(hide_profile: true)
  app.get "/directory_items.json", params: { period: "all", username: person.username }
  raise "Hidden organization leaked through count" unless app.response.parsed_body.fetch("directory_items").first.fetch("svdex_organizations") == 1
  person.user_option.update!(hide_profile: true)
  raise "Private person association leaked through count" unless DiscourseSvdex::CompanyDirectory.member_organization_counts(Guardian.new).fetch(person.id, 0) == 0
  SiteSetting.hide_user_profiles_from_public = true
  raise "Private profiles leaked through count" unless DiscourseSvdex::CompanyDirectory.member_organization_counts(Guardian.new).empty?
  raise ActiveRecord::Rollback
end
puts "PASS Organizations counts explicit public Key people links once per organization; guest serialization, both sort directions and hidden-profile privacy hold"
