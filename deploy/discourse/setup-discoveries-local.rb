# frozen_string_literal: true
# Local visual fixtures only; attribution is never imported to production.
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
actor = User.find_by!(username: "svdex")
[
  ["northstar", "discovered", "svdex"],
  ["svdex-fund-i", "discovered", "svdex"],
  ["daniel-park", "discovered", "svdex"],
  ["svdex-company", "self_listed", "svdex-company"],
].each do |username, provenance, contributor|
  entity = User.find_by(username: username)
  next unless entity && DiscourseSvdex::Discoveries.kind(entity)
  row = DiscourseSvdex::Discoveries.capture!(entity, listed_at: nil)
  next if row.contributor_user_id
  # A fixed fixture timestamp supports stable visual previews, never real credit.
  listed_at = [entity.created_at + 1.second, 1.day.ago].max.utc.iso8601
  DiscourseSvdex::Discoveries.record!(entity, actor, provenance: provenance, status: "accepted", contributor: contributor, listed_at: row.listed_at&.iso8601 || listed_at,
    reason: "Local-only discovery attribution fixture for visual review")
end
puts "Local discovery previews ready."
