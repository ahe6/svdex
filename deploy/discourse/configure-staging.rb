# frozen_string_literal: true
# Fresh, isolated staging content. Never load a production database or credentials.
abort "Isolated staging only" unless GlobalSetting.hostname == "staging.svdex.com" &&
  ENV["SVDEX_STAGING_SETUP"] == "1" && SiteSetting.disable_emails == "yes" &&
  SiteSetting.login_required && !SiteSetting.allow_new_registrations

password = STDIN.read.strip
raise "Staging administrator password required" unless password.length >= 32
actor = User.find_by(username: "svdex") || User.create!(username: "svdex", name: "SVDEX",
  email: "owner@staging.svdex.com", password: password, active: true, approved: true,
  admin: true, trust_level: 4)
raise "Expected staging owner" unless actor.admin? && actor.email == "owner@staging.svdex.com"
actor.email_tokens.update_all(confirmed: true)
ENV["DISCOURSE_DEVELOPER_EMAILS"] = actor.email
ENV["SVDEX_INITIAL_SETUP"] = "1"
load File.join(__dir__, "configure-production.rb")
load File.join(__dir__, "configure-marketplace.rb")
SiteSetting.svdex_private_access_form_url = ""
SiteSetting.enable_google_oauth2_logins = false
SiteSetting.svdex_interest_enabled = true
SiteSetting.svdex_bids_enabled = true
SiteSetting.svdex_interest_public_totals = true
SiteSetting.svdex_interest_staff_preview = true
SiteSetting.svdex_bids_staff_preview = true

companies = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
funds = Group.find_by!(name: SiteSetting.svdex_funds_group_name)
tags = TagGroup.find_by_name_insensitive("Companies")
profiles = [
  ["svdex-company", "SVDEX", "Company research, discussion and private-capital opportunities.",
   {"sector_tag_id" => Tag.find_by!(name: "finance").id, "total_funding_usd" => 2_000_000, "last_valuation_usd" => 10_000_000, "headquarters_country" => "United States"}],
  ["svdex-fund-i", "SVDEX Opportunity Fund I", "Investing in software and infrastructure for private capital markets.",
   {"strategy_focus" => "VC", "aum_usd" => 12_500_000, "vintage_year" => 2026, "fund_life" => "10-year term", "headquarters_country" => "United States"}],
]
profiles.each do |username, name, description, facts|
  user = User.find_by(username: username) || User.create!(username: username, name: name,
    email: "#{username}@example.invalid", password: SecureRandom.hex(32), active: true, approved: true)
  companies.add(user) unless companies.users.exists?(user.id)
  funds.add(user) if username == "svdex-fund-i" && !funds.users.exists?(user.id)
  user.email_tokens.update_all(confirmed: true)
  user.user_profile.update!(bio_raw: description) if user.user_profile.bio_raw.blank?
  tag_name = username == "svdex-company" ? "svdex" : username
  tag = Tag.find_by(name: tag_name) || Tag.create!(name: tag_name)
  tags.tags << tag unless tags.tags.exists?(tag.id)
  facts.merge("company_tag_id" => tag.id).each do |key, value|
    field = DiscourseSvdex::CompanyDirectory::FIELDS.fetch(key)
    user.custom_fields[field] ||= DiscourseSvdex::CompanyDirectory.validate!(key, value)
  end
  user.save_custom_fields
end

[
  ["SVDEX — Pre-seed SAFE", SiteSetting.svdex_public_offerings_category_id, "Company discovery and private-market research.",
   {svdex_instrument_type: "safe", svdex_valuation_cap: "USD 10,000,000", svdex_offering_size: "USD 2,000,000", svdex_minimum: "USD 1000"}],
  ["SVDEX — Convertible Note", SiteSetting.svdex_public_offerings_category_id, "Funding the next stage of company research tools.",
   {svdex_instrument_type: "convertible_note", svdex_valuation_cap: "USD 10,000,000", svdex_conversion_discount: "20%", svdex_interest_rate: "6%", svdex_offering_size: "USD 2,000,000"}],
  ["SVDEX — Preferred Equity", SiteSetting.svdex_private_offerings_category_id, "Company research and data infrastructure.",
   {svdex_instrument_type: "equity", svdex_post_money_valuation_usd: "20000000", svdex_offering_size: "USD 5,000,000", svdex_funds_raised: "USD 2,000,000"}],
].each do |title, category, summary, fields|
  next if Topic.exists?(title: title)
  PostCreator.create!(actor, {title: title, raw: summary, category: category, tags: %w[svdex finance],
    svdex_summary: summary, skip_validations: true, skip_jobs: true}.merge(fields))
end
DirectoryItem.refresh_period!(:all)
raise "Staging isolation changed" unless SiteSetting.disable_emails == "yes" && SiteSetting.login_required && !SiteSetting.allow_new_registrations
puts "Isolated staging structure and content ready."
