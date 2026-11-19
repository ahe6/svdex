# frozen_string_literal: true
# One-time local copies. Re-running preserves edited facts, account links and logos.
# This script must never be part of a production release/configuration command.
profiles = DiscourseSvdex::Prototypes::CompanyProfiles
model = DiscourseSvdex::Prototypes::CompanyProfileRecord
profiles.ensure_local!
profiles.setup!
sources = {}
fund_ids = Group.find_by(name: SiteSetting.svdex_funds_group_name)&.users&.pluck(:id) || []
Group.find_by!(name: SiteSetting.svdex_companies_group_name).users.where(admin: false, moderator: false, active: true, staged: false).find_each do |account|
  kind = fund_ids.include?(account.id) ? "funds" : "companies"
  slug = { "svdex-company" => "svdex", "northstar" => "northstar-instruments" }.fetch(account.username, account.username_lower.tr("_", "-"))
  record = model.find_or_initialize_by(slug: slug)
  if record.new_record?
    keys = profiles::FACTS + (kind == "funds" ? profiles::FUND_FACTS : [])
    facts = keys.to_h { |key| [key, account.custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch(key)]] }
    record.assign_attributes(kind: kind, name: account.name.presence || account.username,
      summary: ActionView::Base.full_sanitizer.sanitize(account.user_profile.bio_excerpt.to_s).truncate(180), facts: facts, listed: true)
    record.save!
  end
  sources[account.id] = [record, account]
end
fields = UserField.public_fields.where(external_type: DiscourseSvdex::PeopleDirectory::FIELD_TYPE).pluck(:external_name, :id).to_h
Group.find_by!(name: SiteSetting.svdex_people_group_name).users.where(admin: false, moderator: false, active: true, staged: false).find_each do |account|
  next if sources.key?(account.id) || account.name.blank?
  record = model.find_or_initialize_by(slug: account.username_lower.tr("_", "-"))
  if record.new_record?
    values = fields.transform_values { |id| account.user_fields[id.to_s].to_s.strip.presence }
    record.assign_attributes(kind: "people", name: account.name, summary: values["background"].to_s.truncate(180), listed: true,
      facts: values.slice(*profiles::PERSON_FACTS).merge("location" => account.user_profile.location.presence))
    record.save!
  end
  sources[account.id] = [record, account]
end
sources.each_value do |record, account|
  record.update!(logo_upload_id: account.uploaded_avatar_id) if record.logo_upload_id.nil? && account.uploaded_avatar_id
  next if record.kind == "people"
  additions = {}
  { "profile_key_people" => "key_people", "profile_related_entities" => "related_entities" }.each do |target, source|
    next if record.facts.key?(target)
    additions[target] = Array(account.custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch(source)]).filter_map do |entry|
      next unless entry.is_a?(Hash)
      linked = sources[entry["user_id"].to_i]&.first
      linked ? { "profile_id" => linked.id, "role" => entry["role"] } : entry.slice("name", "role", "url").except(*(entry["user_id"] ? ["url"] : []))
    end
  end
  record.update!(facts: record.facts.merge(additions)) if additions.any?
end
puts "Independent local profiles: #{model.group(:kind).count.inspect}. Existing accounts unchanged; no ongoing synchronization."

# Explicit stable entity tags. Offerings/events use these, not one new tag per post.
model.find_each do |record|
  group_name, key = record.kind == "people" ? ["People", "topic_tag_id"] : ["Companies", "company_tag_id"]
  next if record.facts[key].present?
  group = TagGroup.find_by_name_insensitive(group_name) || TagGroup.create!(name: group_name)
  tag = Tag.find_by(name: record.slug) || Tag.create!(name: record.slug)
  group.tags << tag unless group.tags.exists?(tag.id)
  record.update!(facts: record.facts.merge(key => tag.id))
end
puts "Stable native entity tags ready."
