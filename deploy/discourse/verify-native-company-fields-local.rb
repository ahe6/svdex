# frozen_string_literal: true
# Rollback-only prototype: no existing company values, schemas or UI are migrated.
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def assert_native_field!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def native_field_login(user, password)
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  # Isolate this simulated client from other suites' login-rate budgets.
  app.remote_addr = "198.18.#{SecureRandom.random_number(256)}.#{SecureRandom.random_number(254) + 1}"
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: user.username, password: password }, headers: headers
  raise "Native field test login failed (#{app.response.status})" unless app.response.status == 200
  [app, headers]
end
before = [User.count, UserField.count, DirectoryColumn.count, Group.count]
ActiveRecord::Base.transaction do
  password = SecureRandom.hex(24)
  make_user = ->(admin = false) do
    user = User.create!(username: "fields_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: 2, admin: admin)
    user.email_tokens.update_all(confirmed: true)
    user
  end
  actor, company, other = make_user.call(true), make_user.call, make_user.call
  group = Group.create!(name: "field_dir_#{SecureRandom.hex(3)}", visibility_level: Group.visibility_levels[:public], members_visibility_level: Group.visibility_levels[:public])
  group.add(company)
  group.add(other)
  attrs = { description: "Company information maintained by staff.", editable: false, show_on_signup: false, show_on_profile: true, show_on_user_card: false, searchable: false, requirement: :optional }
  stage = UserField.create!(**attrs, name: "Company stage", field_type: "dropdown", user_field_options_attributes: [{ value: "Non-venture" }, { value: "Seed" }])
  location = UserField.create!(**attrs, name: "Company location", field_type: "text")
  funding = UserField.create!(**attrs, name: "Company funding", field_type: "text")
  [stage, location, funding].each_with_index { |field, i| DirectoryColumn.create!(name: field.name, user_field: field, type: :user_field, enabled: true, position: 100 + i) }
  staff, headers = native_field_login(actor, password)
  account, account_headers = native_field_login(company, password)
  staff.put "/u/#{company.username}.json", params: { user_fields: { stage.id => "Non-venture", location.id => "United States", funding.id => "9" } }, headers: headers
  assert_native_field!(staff.response.status == 200 && company.reload.user_fields[stage.id.to_s] == "Non-venture", "staff can maintain native company facts through the standard user update endpoint")
  staff.put "/u/#{other.username}.json", params: { user_fields: { funding.id => "100" } }, headers: headers
  assert_native_field!(staff.response.status == 200, "native fields can hold financial disclosures as text")
  account.put "/u/#{company.username}.json", params: { user_fields: { stage.id => "Seed", location.id => "Elsewhere" } }, headers: account_headers
  values = company.reload.user_fields
  assert_native_field!(values[stage.id.to_s] == "Non-venture" && values[location.id.to_s] == "United States", "members cannot overwrite staff-maintained native fields through direct requests")
  guest = ActionDispatch::Integration::Session.new(Rails.application)
  guest.host! "localhost"
  guest.get "/u/#{company.username}.json"
  assert_native_field!(guest.response.status == 200 && guest.response.parsed_body.dig("user", "user_fields", stage.id.to_s) == "Non-venture", "guests can read disclosed native company fields on permitted profiles")
  DirectoryItem.add_missing_users(:all)
  guest.get "/directory_items.json", params: { period: "all", group: group.name, user_field_ids: [stage.id, location.id, funding.id].join("|"), order: funding.name, asc: true }
  data = guest.response.parsed_body
  assert_native_field!(guest.response.status == 200 && data.dig("meta", "total_rows_directory_items") == 2, "native group directory provides counts and company field columns")
  rows = data.fetch("directory_items")
  row = rows.find { |r| r.fetch("id") == company.id }
  assert_native_field!(row.dig("user", "user_fields", stage.id.to_s, "value") == ["Non-venture"], "native directory serializes the public company field without a custom endpoint")
  assert_native_field!(rows.map { |r| r.fetch("id") } == [other.id, company.id], "native text-field sort places 100 before 9; numeric sorting still needs the backend")
  staff.put "/u/#{company.username}.json", params: { user_fields: { funding.id => "not a number" } }, headers: headers
  assert_native_field!(staff.response.status == 200 && company.reload.user_fields[funding.id.to_s] == "not a number", "native text storage does not replace server financial validation")
  raise ActiveRecord::Rollback
end
assert_native_field!(before == [User.count, UserField.count, DirectoryColumn.count, Group.count], "native field prototype leaves no accounts, fields, columns or groups behind")
