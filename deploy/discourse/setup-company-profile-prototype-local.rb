# frozen_string_literal: true
DiscourseSvdex::Prototypes::CompanyProfiles.ensure_local!
DiscourseSvdex::Prototypes::CompanyProfiles.setup!
account = User.find_by!(username: "svdex-company")
record = DiscourseSvdex::Prototypes::CompanyProfileRecord.find_or_initialize_by(slug: "svdex")
if record.new_record?
  record.assign_attributes(name: account.name, summary: ActionView::Base.full_sanitizer.sanitize(account.user_profile.bio_excerpt.to_s), listed: true, official_account: account,
    facts: DiscourseSvdex::Prototypes::CompanyProfiles::FACTS.to_h { |key| [key, account.custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch(key)]] })
  record.save!
end
puts "Independent company: http://localhost:4080/company/#{record.slug}"

# A second independent entry makes directory search, ordering and filtering useful.
northstar = User.find_by(username: "northstar")
if northstar
  company = DiscourseSvdex::Prototypes::CompanyProfileRecord.find_or_initialize_by(slug: "northstar-instruments")
  if company.new_record?
    company.assign_attributes(name: northstar.name, summary: ActionView::Base.full_sanitizer.sanitize(northstar.user_profile.bio_excerpt.to_s), listed: true,
      facts: DiscourseSvdex::Prototypes::CompanyProfiles::FACTS.to_h { |key| [key, northstar.custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch(key)]] })
    company.save!
  end
end
puts "Independent directory: http://localhost:4080/company-directory"

# Retain native uploads independently of any participation account or its avatar.
{"svdex" => account, "northstar-instruments" => northstar}.each do |slug, source|
  next unless source&.uploaded_avatar_id
  profile = DiscourseSvdex::Prototypes::CompanyProfileRecord.find_by(slug: slug)
  profile.update!(logo_upload_id: source.uploaded_avatar_id) if profile && profile.logo_upload_id.nil?
end

# Preserve the existing public associations once, without reading them from the
# organization account at render time or overwriting later independent edits.
{"svdex" => account, "northstar-instruments" => northstar}.each do |slug, source|
  profile = DiscourseSvdex::Prototypes::CompanyProfileRecord.find_by(slug: slug)
  next unless source && profile
  additions = DiscourseSvdex::Prototypes::CompanyProfiles::REFERENCE_FACTS.reject { |key| profile.facts.key?(key) }.to_h do |key|
    [key, source.custom_fields[DiscourseSvdex::CompanyDirectory::FIELDS.fetch(key)]]
  end
  profile.update!(facts: profile.facts.merge(additions)) if additions.any?
end
