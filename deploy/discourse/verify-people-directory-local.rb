# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
companies = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
funds = Group.find_by!(name: SiteSetting.svdex_funds_group_name)
org_ids = GroupUser.joins(:user).where(users: { admin: false, moderator: false }).where(group_id: [companies.id, funds.id]).distinct.pluck(:user_id)
raise "Organization fixtures missing" if org_ids.empty?
app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
maintained = Group.find_by!(name: SiteSetting.svdex_maintained_accounts_group_name)
maintained_ids = maintained.users.pluck(:id)
%w[all weekly].each do |period|
  app.get "/directory_items.json", params: { period: period, order: "username", asc: true }
  raise "Users request failed" unless app.response.status == 200
  expected = DirectoryItem.where(period_type: DirectoryItem.period_types.fetch(period.to_sym)).where.not(user_id: maintained_ids).count
  raise "Users count includes maintained profiles" unless app.response.parsed_body.dig("meta", "total_rows_directory_items") == expected
end
org = User.find(org_ids.first)
app.get "/directory_items.json", params: { period: "all", username: org.username }
raise "Maintained organization entered Users" unless app.response.parsed_body.fetch("directory_items").empty?
people = Group.find_by!(name: SiteSetting.svdex_people_group_name)
raise "People must stay staff-curated" if people.public_admission || people.allow_membership_requests
User.transaction do
  person = User.create!(username: "person_#{SecureRandom.hex(4)}", name: "Directory Person",
    email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2)
  unnamed = User.create!(username: "unnamed_#{SecureRandom.hex(4)}", name: "",
    email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2)
  people.add(person)
  people.add(unnamed)
  people.add(org)
  DirectoryItem.refresh_period!(:all)
  person.user_option.update!(hide_profile: false)
  query = -> { DirectoryItemsQuery.new(user: nil, guardian: Guardian.new).call(period_type: DirectoryItem.period_types[:all], svdex_catalog: "people", group_name: people.name, order: "username") }
  result = query.call
  ids = result.items.map(&:user_id)
  raise "Curated person missing" unless ids.include?(person.id)
  raise "Organization or nameless account entered People" if (ids & [unnamed.id, org.id]).any?
  app.get "/people/directory_items.json", params: { period: "all", group: people.name, name: person.username }
  raise "People search/count failed" unless app.response.status == 200 && app.response.parsed_body.dig("meta", "total_rows_directory_items") == 1
  result = DirectoryItemsQuery.new(user: unnamed, guardian: Guardian.new(unnamed)).call(period_type: DirectoryItem.period_types[:all], svdex_catalog: "people", group_name: people.name, prioritize_user: true)
  raise "Current-user priority bypassed curation" if result.items.any? { |row| row.user_id == unnamed.id }
  SiteSetting.allow_users_to_hide_profile = true
  person.user_option.update!(hide_profile: true)
  raise "Hidden profile leaked into People" if query.call.items.any? { |row| row.user_id == person.id }
  raise ActiveRecord::Rollback
end
app.get "/u/#{org.username}.json"
raise "Company profile became inaccessible" unless app.response.status == 200
puts "PASS Users excludes maintained profiles; People enforces curation, real names, organization exclusion, search, counts and native profile privacy"

User.transaction do
  # Own the test participant rather than relying on a developer's visual-review
  # account, which is deliberately not seeded by a clean installation.
  person = User.create!(username: "directory_#{SecureRandom.hex(4)}", name: "Directory Member",
    email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24),
    active: true, approved: true, trust_level: 2)
  %i[all weekly].each do |period|
    DirectoryItem.refresh_period!(period)
  end
  person.user_option.update!(hide_profile: false)
  organizations = companies.users.where(admin: false, moderator: false).order(:id).limit(2).to_a
  raise "Two public organization fixtures required" unless organizations.length == 2
  field = DiscourseSvdex::CompanyDirectory::FIELDS.fetch("key_people")
  organizations.each do |organization|
    organization.custom_fields[field] = [{ "name" => person.name, "user_id" => person.id }, { "name" => person.name, "user_id" => person.id }]
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
