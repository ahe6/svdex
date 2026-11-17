# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def discovery_check(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def discovery_session(user = nil, password = nil)
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

User.transaction do
  password = SecureRandom.hex(24)
  make_user = ->(admin = false) do
    User.create!(username: "discover_#{SecureRandom.hex(5)}", name: "Discovery verification #{SecureRandom.hex(3)}", email: "#{SecureRandom.hex(10)}@example.invalid", password: password, active: true, approved: true, admin: admin, trust_level: 2).tap do |user|
      user.email_tokens.update_all(confirmed: true)
      user.user_profile.update!(bio_raw: "Professional research and technology work with documented history.")
    end
  end
  actor = make_user.call(true)
  contributor = make_user.call
  other = make_user.call
  guest = Guardian.new
  groups = { "companies" => Group.find_by!(name: SiteSetting.svdex_companies_group_name), "funds" => Group.find_by!(name: SiteSetting.svdex_funds_group_name), "people" => Group.find_by!(name: SiteSetting.svdex_people_group_name) }
  entities = groups.to_h do |kind, group|
    entity = make_user.call
    groups["companies"].add(entity) if kind == "funds"
    group.add(entity)
    [kind, entity]
  end
  entities.each do |type, entity|
    row = DiscourseSvdex::Discovery.find_by!(entity_user_id: entity.id, superseded_by_id: nil)
    discovery_check(row.entity_kind == type && row.provenance == "staff_added" && row.contributor_user_id.nil?, "#{type} indexing does not invent personal discovery credit")
    stamp = row.listed_at
    DiscourseSvdex::Discoveries.capture!(entity)
    discovery_check(row.reload.listed_at == stamp && DiscourseSvdex::Discovery.where(entity_user_id: entity.id).count == 1, "#{type} classification capture is idempotent")
    DiscourseSvdex::Discoveries.record!(entity, actor, provenance: "discovered", contributor: contributor.username, reason: "Reviewed substantive entry and duplicate search")
    row.reload
    original = [row.original_entity_user_id, row.original_contributor_user_id, row.listed_at]
    entity.update!(name: "Updated entity #{SecureRandom.hex(3)}")
    groups[type].remove(entity)
    groups[type].add(entity)
    discovery_check([row.reload.original_entity_user_id, row.original_contributor_user_id, row.listed_at] == original, "#{type} profile edits and reclassification preserve original credit")
  end
  background_field = UserField.public_fields.find_by!(external_type: DiscourseSvdex::PeopleDirectory::FIELD_TYPE, external_name: "background")
  person = entities["people"]
  person.custom_fields["#{User::USER_FIELD_PREFIX}#{background_field.id}"] = "Former engineer at Northstar Instruments."
  person.save_custom_fields
  history = DiscourseSvdex::Discoveries.history(contributor, guest)
  discovery_check(history[:records].find { |row| row[:kind] == "people" }[:background] == "Former engineer at Northstar Instruments.", "discovery previews reuse staff-maintained public People background")
  discovery_check(history[:count] == 3 && history[:records].map { |r| r[:kind] }.sort == groups.keys.sort, "guest history covers Companies, Funds and People")
  first_page = DiscourseSvdex::Discoveries.history(contributor, guest, limit: 1)
  second_page = DiscourseSvdex::Discoveries.history(contributor, guest, page: 1, limit: 1)
  oldest = DiscourseSvdex::Discoveries.history(contributor, guest, order: "oldest")
  discovery_check(first_page[:has_more] && first_page[:count] == 3 && first_page[:records][0][:id] != second_page[:records][0][:id], "pagination keeps exact visible totals and distinct rows")
  discovery_check(oldest[:records].map { |r| r[:id] } == history[:records].reverse.map { |r| r[:id] }, "oldest and newest ordering are deterministic")
  credit = DiscourseSvdex::Discoveries.credit(entities["companies"], guest)
  discovery_check(credit[:contributor][:id] == contributor.id, "entity attribution links to actual stable contributor ID")
  original_row = DiscourseSvdex::Discovery.find_by!(entity_user_id: entities["companies"].id, superseded_by_id: nil)
  date = original_row.listed_at
  DiscourseSvdex::Discoveries.record!(entities["companies"], actor, provenance: "discovered", contributor: contributor.username, listed_at: date.iso8601, reason: "Round-trip native ISO timestamp without loss of precision")
  discovery_check(original_row.reload.listed_at == date, "native timestamp round trips do not lose subsecond precision")
  begin
    DiscourseSvdex::Discoveries.record!(entities["companies"], other, provenance: "discovered", contributor: other.username, reason: "Attempt to take credit")
    raise "Nonstaff changed discovery"
  rescue Discourse::InvalidAccess
  end
  begin
    DiscourseSvdex::Discoveries.record!(entities["companies"], actor, provenance: "discovered", contributor: contributor.username, listed_at: (date - 1.day).iso8601, reason: "Attempted timestamp rewrite")
    raise "Timestamp was overwritten"
  rescue Discourse::InvalidParameters
  end
  discovery_check(original_row.reload.listed_at == date, "staff correction cannot rewrite the original timestamp")
  DiscourseSvdex::Discoveries.record!(entities["companies"], actor, provenance: "discovered", contributor: other.username, reason: "Corrected contributor after source review")
  discovery_check(original_row.reload.original_contributor_user_id == contributor.id && original_row.contributor_user_id == other.id, "corrections retain immutable first contributor and audited corrected credit")
  events = DiscourseSvdex::DiscoveryEvent.where(discovery_id: original_row.id)
  discovery_check(events.last.before_state["contributor_user_id"] == contributor.id && events.last.after_state["contributor_user_id"] == other.id, "audit records both sides of a credit correction")
  begin
    events.last.update!(reason: "Rewrite history")
    raise "Audit event was mutable"
  rescue ActiveRecord::ReadOnlyRecord
  end
  DiscourseSvdex::Discoveries.record!(entities["companies"], actor, status: "withdrawn", provenance: "discovered", contributor: other.username, reason: "Entry invalidated by moderation")
  discovery_check(DiscourseSvdex::Discoveries.credit(entities["companies"], guest).nil? && DiscourseSvdex::Discoveries.history(other, guest)[:count] == 0, "withdrawn discoveries receive no public credit or count")
  # Apply explicit native privacy before both counts and pagination.
  entities["people"].user_option.update!(hide_profile: true)
  discovery_check(DiscourseSvdex::Discoveries.history(contributor, guest)[:count] == 1, "hidden entities do not leak through public counts")
  discovery_check(DiscourseSvdex::Discoveries.credit(entities["people"], guest).nil?, "hidden entity attribution is not exposed")
  entities["people"].user_option.update!(hide_profile: false)
  visibility = [groups["people"].visibility_level, groups["people"].members_visibility_level]
  groups["people"].update!(visibility_level: Group.visibility_levels[:staff], members_visibility_level: Group.visibility_levels[:staff])
  discovery_check(DiscourseSvdex::Discoveries.history(contributor, guest)[:count] == 1 && DiscourseSvdex::Discoveries.credit(entities["people"], guest).nil?, "restricted directory membership is respected by attribution and counts")
  groups["people"].update!(visibility_level: visibility[0], members_visibility_level: visibility[1])
  # Anonymous API, query controls and staff-only recording use native sessions.
  app, = discovery_session
  member, headers = discovery_session(other, password)
  staff, staff_headers = discovery_session(actor, password)
  path = "/listings/discoveries/#{contributor.username}.json"
  app.get path, params: { kind: "funds", order: "oldest" }
  discovery_check(app.response.status == 200 && app.response.parsed_body["records"].map { |r| r["kind"] } == ["funds"], "public API filters by type without exposing staff notes")
  discovery_check(!app.response.body.include?("reason") && !app.response.body.include?("before_state"), "staff evidence and audit snapshots remain private")
  app.get path, params: { kind: "secrets" }
  discovery_check(app.response.status == 400, "invalid history filters are rejected")
  app.get path, params: { page: "-1" }
  discovery_check(app.response.status == 400, "invalid pagination is rejected")
  endpoint = "/listings/discovery-credit/#{entities["funds"].id}.json"
  member.get endpoint, headers: headers
  discovery_check(member.response.status == 403, "ordinary members cannot inspect staff discovery evidence")
  member.put endpoint, params: { discovery: { provenance: "discovered", contributor: other.username, reason: "Attempting to steal discovery credit" } }, headers: headers
  discovery_check(member.response.status == 403, "ordinary members cannot assign or overwrite discovery credit")
  staff.get "/admin/users/#{entities["funds"].id}.json", headers: staff_headers
  discovery_check(staff.response.status == 200 && staff.response.parsed_body["svdex_discovery_entity"] == "funds", "native admin user payload enables discovery controls for curated entities")
  staff.get endpoint, headers: staff_headers
  discovery_check(staff.response.status == 200 && staff.response.parsed_body["events"].any?, "staff can inspect the native administrative audit view")
  staff.put endpoint, params: { discovery: { provenance: "discovered", status: "accepted", contributor: contributor.username, reason: "Confirmed listing provenance and duplicate review", original_contributor_user_id: other.id } }, headers: staff_headers
  discovery_check(staff.response.status == 200 && DiscourseSvdex::Discovery.find_by(entity_user_id: entities["funds"].id).original_contributor_user_id == contributor.id, "staff review API saves permitted fields and rejects mass assignment of original identity")
  groups["people"].add(contributor)
  app.get "/u/#{contributor.username}.json"
  discovery_check(app.response.status == 200 && app.response.parsed_body.dig("user", "svdex_discoveries", "count") == 2, "curated People profiles include the same public discovery preview")
  contributor.user_option.update!(hide_profile: true)
  app.get path
  discovery_check(app.response.status == 404, "hidden contributor history cannot be fetched directly")
  discovery_check(DiscourseSvdex::Discoveries.credit(entities["funds"], guest).nil?, "hidden contributor names are not leaked through entity credit")
  contributor.user_option.update!(hide_profile: false)
  # Self-listing is explicit; it does not imply someone else endorsed the record.
  self_entity = make_user.call
  groups["companies"].add(self_entity)
  DiscourseSvdex::Discoveries.record!(self_entity, actor, provenance: "self_listed", contributor: self_entity.username, reason: "Confirmed representative and self-listing")
  discovery_check(DiscourseSvdex::Discoveries.credit(self_entity, guest)[:provenance] == "self_listed", "self-listing is explicitly distinguished from discovery")
  discovery_check(DiscourseSvdex::Discoveries.history(self_entity, guest)[:count] == 0, "self-listing is not counted as scouting another entity")
  # Native merges must preserve IDs and dates, without silently selecting winners.
  source = entities["funds"]
  target = make_user.call
  groups["companies"].add(target)
  groups["funds"].add(target)
  DiscourseSvdex::Discoveries.record!(target, actor, provenance: "discovered", contributor: other.username, reason: "Substantive second record before duplicate review")
  source_row = DiscourseSvdex::Discovery.find_by!(entity_user_id: source.id, superseded_by_id: nil)
  target_row = DiscourseSvdex::Discovery.find_by!(entity_user_id: target.id, superseded_by_id: nil)
  source_id = source.id
  UserMerger.new(source, target, actor).merge!
  discovery_check(source_row.reload.original_entity_user_id == source_id && source_row.entity_user_id == target.id && target_row.reload.superseded_by_id == source_row.id, "native entity merge retains the source attribution record")
  discovery_check(source_row.reload.status == "disputed" && DiscourseSvdex::Discoveries.credit(target.reload, guest).nil?, "duplicate entity merge requires review before public credit resumes")
  old_contributor_id = contributor.id
  UserMerger.new(contributor, other, actor).merge!
  people_row = DiscourseSvdex::Discovery.find_by!(entity_user_id: entities["people"].id, superseded_by_id: nil)
  discovery_check(people_row.contributor_user_id == other.id && people_row.original_contributor_user_id == old_contributor_id, "native contributor merge follows the surviving account and preserves original ID")
  # Removing a source entity retains audit data but cannot leave a public entry.
  entity_id = entities["people"].id
  DB.exec("DELETE FROM users WHERE id = :id", id: entity_id)
  discovery_check(people_row.reload.entity_user_id.nil? && DiscourseSvdex::DiscoveryEvent.where(discovery_id: people_row.id).exists?, "deleted entities retain historical audit without a dangling public profile")
  discovery_check(DiscourseSvdex::Discoveries.history(other, guest)[:records].none? { |r| r[:entity][:id] == entity_id }, "deleted entity does not contribute a public discovery row")
  puts "Discovery checks complete; all records rolled back."
  raise ActiveRecord::Rollback
end
