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
