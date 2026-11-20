# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
DiscourseSvdex::Prototypes::CompanyProfiles.setup!
Catalog = DiscourseSvdex::Prototypes::CompanyCatalog
Document = DiscourseSvdex::Prototypes::CatalogDocument
Profiles = DiscourseSvdex::Prototypes::CompanyProfileRecord
PublicCatalog = DiscourseSvdex::Prototypes::PublicCatalog

def catalog_assert!(value, message)
  raise message unless value
  puts "PASS #{message}"
end
def catalog_session(user = nil, password = nil)
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
original_contact = SiteSetting.svdex_private_access_contact
original_pm_groups = SiteSetting.personal_message_enabled_groups
begin
  User.transaction do
    password = SecureRandom.hex(24)
    staff = User.create!(username: "cadmin_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, admin: true)
    member = User.create!(username: "cmember_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: 0)
    stranger = User.create!(username: "cother_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: 2)
    [staff, member, stranger].each { |user| user.email_tokens.update_all(confirmed: true) }
    SiteSetting.svdex_private_access_contact = staff.username
    SiteSetting.personal_message_enabled_groups = "1|2|11"
    import = ->(documents, apply: false) do
      entries = documents.map { |document| { "kind" => "companies", "document" => document } }
      PublicCatalog.import!({ "format" => DiscourseSvdex::Prototypes::PublicCatalogDocument::FORMAT, "entries" => entries }, actor: staff, apply: apply)
    end
    Document.read_directory("/tmp/svdex-company-catalog-input").each { |entry| Catalog.attributes(entry, Guardian.new(staff)) }
    doc = Document.read_directory("/tmp/svdex-company-catalog-input").first.deep_dup
    doc["id"] = "catalog-#{SecureRandom.hex(4)}"
    count = User.count
    result = import.call([doc])
    catalog_assert!(result.first[:changed] && !Profiles.exists?(catalog_key: doc["id"]), "default catalog preview never writes company data")
    import.call([doc], apply: true)
    record = Profiles.find_by!(catalog_key: doc["id"])
    catalog_assert!(record.name == doc["name"] && record.listed && record.official_account_id.nil? && User.count == count, "reviewed import publishes independent facts without creating an account")
    catalog_assert!(record.facts["total_funding_usd"].nil? && record.catalog_revision == Document.revision(doc), "unknown figures remain unknown and carry a content revision")
    timestamp = record.updated_at
    import.call([doc], apply: true)
    catalog_assert!(record.reload.updated_at == timestamp, "re-importing the same content is idempotent")
    guest, = catalog_session
    signed, headers = catalog_session(member, password)
    admin, admin_headers = catalog_session(staff, password)
    path = "/company-profiles/#{record.slug}.json"
    guest.get path
    catalog_assert!(guest.response.status == 200 && guest.response.parsed_body.dig("profile", "catalog_managed") && !guest.response.parsed_body.key?("editor"), "published file-backed profiles retain the existing public profile response")
    admin.put path, params: { profile: { name: "Silent overwrite" } }, headers: admin_headers
    catalog_assert!(admin.response.status == 400 && record.reload.name == doc["name"], "even staff cannot silently overwrite file-owned facts through the old editor")
    admin.put path, params: { profile: { official_username: member.username } }, headers: admin_headers
    catalog_assert!(admin.response.status == 200 && record.reload.official_account_id == member.id, "operational account linking remains independent of public-file ownership")
    suggestion = { revision: record.catalog_revision, name: "SVDEX Research", reason: "The public company website now uses this name." }
    proposal_path = "/company-profiles/#{record.slug}/suggestions.json"
    guest.post proposal_path, params: { suggestion: suggestion }
    catalog_assert!(guest.response.status == 403, "corrections require a signed-in account")
    signed.post proposal_path, params: { suggestion: suggestion }, headers: headers
    catalog_assert!(signed.response.status == 200, "brand-new members can submit corrections without GitHub or general private-message permissions")
    url = signed.response.parsed_body.fetch("url")
    catalog_assert!(!Guardian.new(member).can_send_private_messages?, "staff intake does not grant general private-message permissions")
    topic = Topic.find_by!(title: "Company correction: #{record.name}", user_id: member.id)
    catalog_assert!(topic.archetype == Archetype.private_message && topic.topic_allowed_users.pluck(:user_id).sort == [staff.id, member.id].sort, "correction uses the native private staff inbox and submitter access")
    catalog_assert!(!topic.first_post.raw.include?("schema_version") && topic.first_post.raw.include?(suggestion[:name]), "native review threads show readable proposed changes instead of file-format internals")
    catalog_assert!(record.reload.name == doc["name"], "submitting a proposal never publishes or changes company facts")
    guest.get "#{url}.json"
    catalog_assert!([403, 404].include?(guest.response.status), "correction details are not public")
    outsider, outsider_headers = catalog_session(stranger, password)
    outsider.get "#{url}.json", headers: outsider_headers
    catalog_assert!([403, 404].include?(outsider.response.status), "another member cannot read the correction")
    proposed = Catalog.proposal_document!(topic.reload, staff)
    catalog_assert!(proposed["name"] == suggestion[:name] && proposed["id"] == doc["id"], "staff can prepare the submitted fields as a validated data-file proposal")
    begin
      Catalog.proposal_document!(topic, member)
      raise "member exported a staff proposal"
    rescue Discourse::InvalidAccess
      puts "PASS proposed-file export remains staff-only"
    end
    import.call([proposed], apply: true)
    catalog_assert!(record.reload.name == suggestion[:name] && record.official_account_id == member.id && record.listed, "reviewed import updates public facts while preserving account link and publication state")
    signed.post proposal_path, params: { suggestion: suggestion }, headers: headers
    catalog_assert!(signed.response.status == 400, "a stale correction form cannot overwrite a newer review revision")
    begin
      Catalog.proposal_document!(topic.reload, staff)
      raise "stale proposal exported"
    rescue Document::Invalid
      puts "PASS exporting an old proposal requires reconciliation with newer data"
    end
    record.update!(summary: "A direct database edit that has not been reconciled.")
    begin
      import.call([proposed], apply: true)
      raise "database drift overwritten"
    rescue Document::Invalid
      puts "PASS database drift is detected instead of silently overwritten"
    end
    record.update!(summary: proposed["summary"])
    changed = proposed.deep_dup
    changed["summary"] = "Reviewed company research infrastructure."
    invalid = doc.deep_dup
    invalid["id"] = "invalid-#{SecureRandom.hex(4)}"
    invalid["stage"] = "not-a-configured-stage"
    begin
      import.call([changed, invalid], apply: true)
      raise "invalid batch imported"
    rescue Document::Invalid, Discourse::InvalidParameters
      catalog_assert!(record.reload.summary == proposed["summary"], "an invalid batch rolls back earlier company writes")
    end
    raise ActiveRecord::Rollback
  end
ensure
  SiteSetting.svdex_private_access_contact = original_contact
  SiteSetting.personal_message_enabled_groups = original_pm_groups
end
puts "Company catalog checks complete; test users, messages and facts rolled back."
