# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def management_assert!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end
User.transaction do
  maintained = Group.find_by!(name: SiteSetting.svdex_maintained_accounts_group_name)
  people = Group.find_by!(name: SiteSetting.svdex_people_group_name)
  companies = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
  funds = Group.find_by!(name: SiteSetting.svdex_funds_group_name)
  make_user = lambda do |name|
    user = User.create!(username: "#{name}_#{SecureRandom.hex(4)}", name: name.capitalize,
      email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2)
    user.user_option.update!(hide_profile: false)
    user
  end
  human, company, fund, curated = %w[human company fund curated].map(&make_user)
  companies.add(company)
  companies.add(fund)
  funds.add(fund)
  people.add(curated)
  maintained.add(curated)
  DirectoryItem.refresh_period!(:all)
  guest = ActionDispatch::Integration::Session.new(Rails.application)
  guest.host! "localhost"
  fetch_rows = lambda do |params = {}|
    guest.get "/directory_items.json", params: { period: "all", order: "username", asc: true }.merge(params)
    raise "Users request failed" unless guest.response.status == 200
    guest.response.parsed_body
  end
  [human, company, fund].each do |user|
    rows = fetch_rows.call(username: user.username).fetch("directory_items")
    management_assert!(rows.map { |row| row["id"] } == [user.id], "independently managed #{user.username.split('_').first} appears without any posting/login requirement")
  end
  management_assert!(fetch_rows.call(username: curated.username).fetch("directory_items").empty?, "maintained person stays out of Users")
  maintained.add(company)
  maintained.add(fund)
  [company, fund, curated].each do |user|
    %i[username name].each do |search_key|
      data = fetch_rows.call(search_key => user.username)
      management_assert!(data.fetch("directory_items").empty? && data.dig("meta", "total_rows_directory_items") == 0, "management exclusion applies before #{search_key} search counts")
    end
  end
  data = fetch_rows.call(username: curated.username, svdex_catalog: "people")
  management_assert!(data.fetch("directory_items").empty?, "request parameters cannot turn native Users into a maintained-profile catalog")
  data = fetch_rows.call(group: companies.name)
  management_assert!((data.fetch("directory_items").map { |row| row["id"] } & [company.id, fund.id]).empty?, "Users group filters cannot reintroduce maintained organizations")
  native = DirectoryItemsQuery.new(user: company, guardian: Guardian.new(company)).call(period_type: DirectoryItem.period_types[:all], prioritize_user: true, limit: 1)
  management_assert!(!native.items.any? { |row| [company.id, fund.id, curated.id].include?(row.user_id) }, "native signed-in user prioritization cannot reinsert maintained profiles")
  guest.get "/listings/company-directory.json", params: { kind: "all", name: company.username }
  management_assert!(guest.response.status == 200 && guest.response.parsed_body.fetch("directory_items").any? { |row| row["id"] == company.id }, "managed companies remain in their catalog")
  guest.get "/listings/company-directory.json", params: { kind: "funds", name: fund.username }
  management_assert!(guest.response.status == 200 && guest.response.parsed_body.fetch("directory_items").any? { |row| row["id"] == fund.id }, "managed funds remain in their catalog")
  guest.get "/people/directory_items.json", params: { name: curated.username, limit: 1 }
  data = guest.response.parsed_body
  management_assert!(guest.response.status == 200 && data.fetch("directory_items").map { |row| row["id"] } == [curated.id], "managed people remain in their curated catalog")
  more = data.dig("meta", "load_more_directory_items")
  management_assert!(URI.parse(more).path == "/people/directory_items.json", "People pagination stays in its catalog scope")
  maintained.remove(company)
  management_assert!(fetch_rows.call(username: company.username).fetch("directory_items").map { |row| row["id"] } == [company.id], "explicit handover makes an organization appear in Users")
  management_assert!(companies.users.exists?(company.id), "handover preserves company classification")
  management_assert!(!Guardian.new(human).can_see_group?(maintained) && !Guardian.new(human).can_edit?(maintained), "ordinary members cannot see or edit the management group")
  management_assert!(!maintained.public_admission && !maintained.public_exit && !maintained.allow_membership_requests, "members cannot self-join, leave or request management classification")
  before = maintained.users.pluck(:id)
  people.remove(curated)
  management_assert!(maintained.users.pluck(:id).sort == before.sort, "catalog membership does not change account management")
  raise ActiveRecord::Rollback
end
puts "Account management checks complete; all test records rolled back."
