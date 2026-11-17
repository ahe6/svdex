# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def people_assert!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def people_login(user, password)
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.remote_addr = "198.18.#{SecureRandom.random_number(256)}.#{SecureRandom.random_number(254) + 1}"
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: user.username, password: password }, headers: headers
  raise "People test login failed" unless app.response.status == 200
  [app, headers]
end
User.transaction do
  password = SecureRandom.hex(24)
  person = User.create!(username: "facts_#{SecureRandom.hex(4)}", name: "Professional Person", email: "#{SecureRandom.hex(8)}@example.invalid",
    password: password, active: true, approved: true, trust_level: 2)
  actor = User.create!(username: "staff_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid",
    password: password, admin: true, active: true, approved: true)
  [person, actor].each { |account| account.email_tokens.update_all(confirmed: true) }
  people = Group.find_by!(name: SiteSetting.svdex_people_group_name)
  people.add(person)
  person.user_profile.update!(bio_raw: "Research and infrastructure.", location: "New York, US")
  DirectoryItem.refresh_period!(:all)
  fields = UserField.where(external_type: DiscourseSvdex::PeopleDirectory::FIELD_TYPE).index_by(&:external_name)
  people_assert!(fields.length == DiscourseSvdex::PeopleDirectory::FIELDS.length && fields.values.all? { |field| !field.editable && !field.show_on_signup && field.optional? && field.show_on_profile }, "People facts are optional public native fields maintained by staff")
  staff, headers = people_login(actor, password)
  values = { "background" => "Previously built infrastructure tools.", "role" => "Founder", "focus" => "Infrastructure", "net_worth" => "$10–20M" }
  staff.put "/u/#{person.username}.json", params: { user_fields: values.to_h { |key, value| [fields.fetch(key).id, value] } }, headers: headers
  people_assert!(staff.response.status == 200 && person.reload.user_fields[fields.fetch("role").id.to_s] == "Founder", "staff maintain professional facts through the native user editor")
  owner, owner_headers = people_login(person, password)
  owner.put "/u/#{person.username}.json", params: { user_fields: { fields.fetch("net_worth").id => "$1B", fields.fetch("role").id => "Changed" } }, headers: owner_headers
  people_assert!(person.reload.user_fields[fields.fetch("role").id.to_s] == "Founder" && person.user_fields[fields.fetch("net_worth").id.to_s] == "$10–20M", "members cannot overwrite staff-maintained role or net worth")
  guest = ActionDispatch::Integration::Session.new(Rails.application)
  guest.host! "localhost"
  load_person = lambda do
    guest.get "/people/directory_items.json", params: { period: "all", group: people.name, username: person.username }
    raise "People directory failed" unless guest.response.status == 200
    guest.response.parsed_body.fetch("directory_items").first.dig("user", "svdex_person")
  end
  %w[true false].each do |ascending|
    result = DirectoryItemsQuery.new(user: nil, guardian: Guardian.new).call(period_type: DirectoryItem.period_types[:all], svdex_catalog: "people", group_name: people.name, order: "username", ascending: ascending == "true")
    names = result.items.map { |row| row.user.name.strip.downcase }
    people_assert!(names == (ascending == "true" ? names.sort : names.sort.reverse), "Person sorts the displayed real names #{ascending == 'true' ? 'ascending' : 'descending'}")
  end
  facts = load_person.call
  people_assert!(facts["role"] == "Founder" && facts["focus"] == "Infrastructure" && facts["location"] == "New York, US" && facts["background"] == "Previously built infrastructure tools.", "guests see professional facts, dedicated past background and native location")
  staff.put "/u/#{person.username}.json", params: { user_fields: { fields.fetch("background").id => "" } }, headers: headers
  people_assert!(load_person.call["background"].nil?, "missing background stays blank rather than falling back to the present-tense biography")
  owner.put "/u/#{person.username}.json", params: { user_fields: { fields.fetch("background").id => "Changed" } }, headers: owner_headers
  people_assert!(load_person.call["background"].nil?, "members cannot overwrite staff-maintained background")
  people_assert!(facts["net_worth"].nil?, "unsupported personal wealth figures are withheld")
  source = { "net_worth_source" => "https://example.com/estimate", "net_worth_date" => Date.current.iso8601, "net_worth_basis" => "Published range; ownership and illiquidity assumptions apply." }
  staff.put "/u/#{person.username}.json", params: { user_fields: source.to_h { |key, value| [fields.fetch(key).id, value] } }, headers: headers
  estimate = load_person.call.fetch("net_worth")
  people_assert!(estimate["value"] == "$10–20M" && estimate["source"] == source["net_worth_source"] && estimate["basis"] == source["net_worth_basis"], "sourced estimates include the range, date and basis")
  %w[javascript:alert(1) https://user:password@example.com/estimate http://example.com/estimate].each do |url|
    people_assert!(DiscourseSvdex::PeopleDirectory.estimate(values.merge(source).merge("net_worth_source" => url)).nil?, "unsafe estimate source is rejected")
  end
  people_assert!(DiscourseSvdex::PeopleDirectory.estimate(values.merge(source).merge("net_worth_date" => "2026-02-30")).nil?, "invalid estimate dates are rejected")
  organization = Group.find_by!(name: SiteSetting.svdex_companies_group_name).users.where(admin: false, moderator: false).first!
  field = DiscourseSvdex::CompanyDirectory::FIELDS.fetch("key_people")
  organization.custom_fields[field] = [{ "name" => person.name, "user_id" => person.id, "role" => "Founder" }] * 2
  organization.save_custom_fields
  public_reference = DiscourseSvdex::CompanyDirectory.public_references([{ "name" => person.name, "user_id" => person.id, "role" => "Founder" }], Guardian.new).first
  people_assert!(public_reference["url"] == person.relative_url, "organization profiles use the supported native person profile URL")
  refs = load_person.call.fetch("organizations")
  people_assert!(refs.length == 1 && refs.first["url"] == "/u/#{organization.username}/summary", "explicit organization links are deduplicated and link to the native summary")
  guest.get "/u/#{person.username}.json"
  profile_refs = guest.response.parsed_body.dig("user", "svdex_affiliations")
  people_assert!(profile_refs.length == 1 && profile_refs.first["id"] == organization.id && profile_refs.first["role"] == "Founder", "People Summary affiliations reuse the deduplicated directory links and roles")
  people_assert!(profile_refs.first["avatar_template"].present? && profile_refs.first["username"] == organization.username, "affiliations use native account identities and avatars")
  guest.get "/u/#{organization.username}.json"
  people_assert!(!guest.response.parsed_body["user"].key?("svdex_affiliations"), "organization profiles do not get the People affiliation section")
  guest.get "/people/directory_items.json", params: { svdex_organization: organization.id, svdex_location: "New York, US", name: person.username, limit: 1 }
  filtered = guest.response.parsed_body
  people_assert!(guest.response.status == 200 && filtered.fetch("directory_items").map { |row| row["id"] } == [person.id] && filtered.dig("meta", "total_rows_directory_items") == 1, "organization, location and name filters combine before pagination/counts")
  more = CGI.parse(URI.parse(filtered.dig("meta", "load_more_directory_items")).query)
  people_assert!(more["svdex_organization"] == [organization.id.to_s] && more["svdex_location"] == ["New York, US"], "People pagination preserves applied filters")
  people_assert!(filtered.dig("meta", "organizations").any? { |entry| entry["id"] == organization.id } && filtered.dig("meta", "locations").include?("New York, US"), "filter choices come from accessible people and linked organizations")
  guest.get "/people/directory_items.json", params: { svdex_location: "Not a disclosed location" }
  people_assert!(guest.response.parsed_body.fetch("directory_items").empty? && guest.response.parsed_body.dig("meta", "total_rows_directory_items") == 0, "unmatched filters return a consistent empty result")
  guest.get "/people/directory_items.json", params: { svdex_organization: "invalid" }
  people_assert!(guest.response.status == 400, "invalid organization filters are rejected")
  funds = Group.find_by!(name: SiteSetting.svdex_funds_group_name)
  original_fund = funds.users.exists?(organization.id)
  visibility = [funds.visibility_level, funds.members_visibility_level]
  funds.add(organization) unless original_fund
  funds.update!(visibility_level: Group.visibility_levels[:staff], members_visibility_level: Group.visibility_levels[:staff])
  guest.get "/u/#{person.username}.json"
  people_assert!(guest.response.parsed_body.dig("user", "svdex_affiliations").empty?, "restricted fund membership cannot leak through public affiliations")
  funds.update!(visibility_level: visibility[0], members_visibility_level: visibility[1])
  funds.remove(organization) unless original_fund
  SiteSetting.allow_users_to_hide_profile = true
  organization.user_option.update!(hide_profile: true)
  people_assert!(load_person.call.fetch("organizations").empty?, "hidden organizations do not leak through People associations")
  guest.get "/people/directory_items.json", params: { svdex_organization: organization.id }
  people_assert!(guest.response.parsed_body.fetch("directory_items").empty? && guest.response.parsed_body.dig("meta", "organizations").none? { |entry| entry["id"] == organization.id }, "hidden organizations cannot be inferred through filter choices or results")
  guest.get "/u/#{person.username}.json"
  people_assert!(guest.response.parsed_body.dig("user", "svdex_affiliations").empty?, "hidden organizations do not leak through Summary affiliations")
  person.user_profile.update!(location: "Hidden test location")
  person.user_option.update!(hide_profile: true)
  guest.get "/people/directory_items.json"
  people_assert!(!guest.response.parsed_body.dig("meta", "locations").include?("Hidden test location"), "hidden people do not contribute location filter choices")

  guest.get "/directory_items.json", params: { period: "all", username: person.username }
  people_assert!(!guest.response.parsed_body.fetch("directory_items").first.fetch("user").key?("svdex_person"), "Users keeps its native stats and does not receive People payloads")
  raise ActiveRecord::Rollback
end
puts "People facts checks complete; all test records rolled back."
