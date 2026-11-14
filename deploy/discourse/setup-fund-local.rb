# frozen_string_literal: true
# Local directory fixture. Never package or run this as production data setup.
abort "Local fund setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
companies = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
funds = Group.find_by!(name: SiteSetting.svdex_funds_group_name)
sponsor = User.find_by!(username: "svdex-company")
user = User.find_by(username: "svdex-fund-i")
if user && (!companies.users.exists?(id: user.id) || !funds.users.exists?(id: user.id))
  abort "Existing account is not the local fund fixture"
end
created = user.nil?
User.transaction do
  user ||= User.create!(username: "svdex-fund-i", name: "SVDEX Opportunity Fund I",
    email: "svdex-fund-i@example.invalid", password: SecureRandom.hex(32),
    active: true, approved: true, trust_level: 1)
  [companies, funds].each { |group| group.add(user) unless group.users.exists?(id: user.id) }
  if created
    user.email_tokens.update_all(confirmed: true)
    profile = user.user_profile
    profile.update!(bio_raw: "Investing in software and infrastructure for private capital markets.") if profile.bio_raw.blank?
    if !user.uploaded_avatar_id && sponsor.uploaded_avatar_id
      UserAvatar.pick_for_user!(user, sponsor.uploaded_avatar_id, type: :custom)
    end
    tag_group = TagGroup.find_by_name_insensitive("Companies") || raise("Missing Companies tag group")
    tag = Tag.find_by(name: "svdex-fund-i") || Tag.create!(name: "svdex-fund-i")
    tag_group.tags << tag unless tag_group.tags.exists?(id: tag.id)
    values = {
      "manager_name" => "SVDEX", "manager_url" => "http://localhost:4080/u/#{sponsor.username}/summary",
      "strategy_focus" => "VC", "headquarters_country" => "United States",
      "aum_usd" => 12_500_000, "fund_size_usd" => 20_000_000, "fund_size_basis" => "target", "vintage_year" => 2026,
      "fund_life" => "10-year term", "company_tag_id" => tag.id,
    }
    values.each do |key, value|
      field = DiscourseSvdex::CompanyDirectory::FIELDS.fetch(key)
      user.custom_fields[field] = DiscourseSvdex::CompanyDirectory.validate!(key, value) if user.custom_fields[field].nil?
    end
    user.save_custom_fields
  end
end
# Populate the distinct local AUM example without recasting the fundraising target.
aum_field = DiscourseSvdex::CompanyDirectory::FIELDS.fetch("aum_usd")
if user.custom_fields[aum_field].nil?
  user.custom_fields[aum_field] = DiscourseSvdex::CompanyDirectory.validate!("aum_usd", 12_500_000)
  user.save_custom_fields
end
# Shorten only the known original local fixture strategy; preserve other edits.
strategy_field = DiscourseSvdex::CompanyDirectory::FIELDS.fetch("strategy_focus")
if user.custom_fields[strategy_field] == "VC · Financial infrastructure"
  user.custom_fields[strategy_field] = "VC"
  user.save_custom_fields
end
DirectoryItem.refresh_period!(:all) if created
puts "Local fund ready: #{user.name} (/u/#{user.username}/summary). Existing edits retained."
