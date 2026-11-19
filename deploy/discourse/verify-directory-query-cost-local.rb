# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

def directory_cost_assert!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def directory_sql_count
  count = 0
  listener = ->(_name, _start, _finish, _id, event) do
    count += 1 unless event[:cached] || event[:name] == "SCHEMA" || event[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)
  end
  ActiveRecord::Base.uncached do
    ActiveSupport::Notifications.subscribed(listener, "sql.active_record") { yield }
  end
  count
end

# Inspect only profile IDs, not personal data or SQL text. Each query gets a
# fresh guardian, so this also detects accidental whole-catalog visibility scans.
class DirectoryCostGuardian < Guardian
  attr_reader :profile_checks
  def can_see_profile?(user)
    (@profile_checks ||= []) << user.id if user
    super
  end
end

User.transaction do
  companies = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
  people = Group.find_by!(name: SiteSetting.svdex_people_group_name)
  company_tag = DiscourseSvdex::CompanyDirectory.tag_options("Companies", Guardian.new).first
  directory_cost_assert!(company_tag.present?, "local company tags exist for directory query verification")
  create_account = ->(prefix, group) do
    token = SecureRandom.hex(4)
    user = User.create!(username: "#{prefix}_#{token}", name: "#{prefix.capitalize} #{token}",
      email: "#{token}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2)
    group.add(user)
    user
  end
  organizations = Array.new(8) do
    user = create_account.call("queryorg", companies)
    user.custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch("company_tag_id")] = company_tag[:id]
    user.save_custom_fields
    user
  end
  persons = Array.new(6) { create_account.call("queryperson", people) }
  DirectoryItem.refresh_period!(:all)

  # Cold associations and disabled SQL caching make repeated per-row lookups
  # observable. Increasing a page from one to eight rows needs only batch loads.
  measure = ->(ids) do
    users = User.where(id: ids).to_a
    directory_sql_count { DiscourseSvdex::CompanyDirectory.populate(users, Guardian.new) }
  end
  one = measure.call([organizations.first.id])
  many = measure.call(organizations.map(&:id))
  puts "Directory fact queries: one row=#{one}, eight rows=#{many}"
  directory_cost_assert!(many <= one + 2, "company fact query count stays bounded as rows increase")

  measure_people = ->(ids) do
    users = User.where(id: ids).to_a
    directory_sql_count { DiscourseSvdex::PeopleDirectory.populate(users, Guardian.new) }
  end
  one_person = measure_people.call([persons.first.id])
  many_people = measure_people.call(persons.map(&:id))
  puts "People fact queries: one row=#{one_person}, six rows=#{many_people}"
  directory_cost_assert!(many_people <= one_person + 2, "People fact query count stays bounded as rows increase")

  [["companies", companies, organizations, "svdex_total_funding"], ["people", people, persons, "username"]].each do |catalog, group, accounts, order|
    guardian = DirectoryCostGuardian.new
    target = accounts.first
    result = DirectoryItemsQuery.new(user: nil, guardian: guardian).call(
      period_type: DirectoryItem.period_types[:all], group_name: group.name,
      svdex_catalog: catalog, username: target.username, order: order, limit: 1, prioritize_user: false)
    directory_cost_assert!(result.total == 1 && result.items.map(&:user_id) == [target.id], "#{catalog} username search keeps exact totals and pagination")
    inspected = guardian.profile_checks.to_a & accounts.map(&:id)
    directory_cost_assert!(inspected == [target.id], "#{catalog} checks visibility only for search candidates")
  end
  raise ActiveRecord::Rollback
end
puts "Directory query cost checks complete; all records rolled back."
