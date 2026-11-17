# frozen_string_literal: true
# Local visual fixtures only; never imported by production release packaging.
abort "Local fixtures only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
maintained = Group.find_by!(name: SiteSetting.svdex_maintained_accounts_group_name)
people = Group.find_by!(name: SiteSetting.svdex_people_group_name)
[
  ["maya-chen", "Maya Chen", "Investing in financial infrastructure and early-stage software."],
  ["daniel-park", "Daniel Park", "Building tools for company research and private markets."],
].each do |username, name, bio|
  user = User.find_by(username: username)
  if user && (!people.users.exists?(user.id) || user.email != "#{username}@example.invalid")
    raise "Existing account is not a local People fixture"
  end
  unless user
    user = User.create!(username: username, name: name, email: "#{username}@example.invalid",
      password: SecureRandom.hex(32), active: true, approved: true, trust_level: 2)
    user.user_profile.update!(bio_raw: bio)
  end
  user.update!(trust_level: 2) if user.trust_level < 2
  people.add(user) unless people.users.exists?(user.id)
  maintained.add(user) unless maintained.users.exists?(user.id)
end
# Professional facts are native staff fields; leave net worth undisclosed until
# there is a reviewed source, date and basis. Preserve manual local edits.
fields = UserField.where(external_type: DiscourseSvdex::PeopleDirectory::FIELD_TYPE).index_by(&:external_name)
{
  "maya-chen" => ["Partner", "Financial infrastructure", "San Francisco, US", "svdex-fund-i", "Former engineer at Northstar Instruments."],
  "daniel-park" => ["Founder", "Private markets", "New York, US", "svdex-company", "Computer science student at Westbridge University."],
}.each do |username, (role, focus, location, organization_username, background)|
  user = people.users.find_by!(username: username)
  { "role" => role, "focus" => focus, "background" => background }.each do |key, value|
    user.custom_fields["#{User::USER_FIELD_PREFIX}#{fields.fetch(key).id}"] ||= value
  end
  user.save_custom_fields
  user.user_profile.update!(location: location) if user.user_profile.location.blank?
  organization = User.find_by(username: organization_username)
  next unless organization && DiscourseSvdex::CompanyDirectory.company?(organization)
  field = DiscourseSvdex::CompanyDirectory::FIELDS.fetch("key_people")
  entries = Array(organization.custom_fields[field])
  unless entries.any? { |entry| entry.is_a?(Hash) && entry["user_id"].to_i == user.id }
    organization.custom_fields[field] = entries + [{ "name" => user.name, "user_id" => user.id, "role" => role }]
    organization.save_custom_fields
  end
end
# Only explicitly known local fixtures are classified here. Never classify all
# companies/funds as maintained: independent organization accounts are Users too.
User.where(username: %w[svdex-company northstar svdex-fund-i]).each do |organization|
  next unless organization.email == "#{organization.username}@example.invalid"
  maintained.add(organization) unless maintained.users.exists?(organization.id)
end
DirectoryItem.refresh_period!(:all)
puts "Local People profiles ready."
