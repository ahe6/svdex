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
