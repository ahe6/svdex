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
ENV["SVDEX_CONFIGURE_UPGRADE"] = "1"
load File.join(__dir__, "configure-upgrade-production.rb")
load File.join(__dir__, "configure-marketplace.rb")
ENV["SVDEX_RETIRE_INFORMATION_PAGES"] = "1"
load File.join(__dir__, "retire-information-pages.rb")
SiteSetting.svdex_private_access_form_url = ""
SiteSetting.enable_google_oauth2_logins = false
SiteSetting.allow_index_in_robots_txt = false
SiteSetting.enable_sitemap = false
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
  Group.find_by!(name: SiteSetting.svdex_maintained_accounts_group_name).add(user) if user.email == "#{username}@example.invalid"
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
# Isolated preview fixtures for the new catalog surfaces. This file is included
# only in --staging bundles and its hostname/email/signup guard runs first.
people = Group.find_by!(name: SiteSetting.svdex_people_group_name)
maintained = Group.find_by!(name: SiteSetting.svdex_maintained_accounts_group_name)
person = User.find_by(username: "maya-chen") || User.create!(username: "maya-chen", name: "Maya Chen",
  email: "maya-chen@example.invalid", password: SecureRandom.hex(32), active: true, approved: true, trust_level: 2)
raise "Unexpected staging person" unless person.email == "maya-chen@example.invalid"
people.add(person) unless people.users.exists?(person.id)
maintained.add(person) unless maintained.users.exists?(person.id)
person.user_profile.update!(bio_raw: "Investing in financial infrastructure and early-stage software.", location: "New York, US") if person.user_profile.bio_raw.blank?
background = UserField.find_by!(external_type: DiscourseSvdex::PeopleDirectory::FIELD_TYPE, external_name: "background")
person.custom_fields["#{User::USER_FIELD_PREFIX}#{background.id}"] ||= "Former engineer at Northstar Instruments."
person.save_custom_fields
fund = User.find_by!(username: "svdex-fund-i")
key_people = DiscourseSvdex::CompanyDirectory::FIELDS.fetch("key_people")
fund.custom_fields[key_people] ||= [{"name" => person.name, "user_id" => person.id, "role" => "Managing Partner"}]
fund.save_custom_fields
presales = Category.find(SiteSetting.svdex_presales_category_id)
title = "SVDEX Research — Annual early access"
unless Topic.exists?(title: title, category_id: presales.id)
  PostCreator.create!(User.find_by!(username: "svdex-company"), title: title,
    raw: "Company research and private-market data in one workspace. Use this thread for product questions and updates.",
    category: presales.id, tags: %w[finance], svdex_presale_summary: "Company research and private-market data in one workspace.",
    svdex_presale_price: "$120 per year", svdex_presale_includes: "12 months of research tools", svdex_presale_delivery: "Access from January 2027",
    svdex_presale_terms: "One named user.", skip_validations: true, skip_jobs: true)
end
products = Category.find(SiteSetting.svdex_products_category_id)
product_title = "SVDEX Research"
unless Topic.exists?(title: product_title, category_id: products.id)
  campaign = Topic.find_by(title: title, category_id: presales.id)
  links = ["[Company profile](/u/svdex-company/summary)"]
  links << "[Pre-sale campaign](/t/#{campaign.slug}/#{campaign.id})" if campaign
  PostCreator.create!(User.find_by!(username: "svdex-company"), title: product_title,
    raw: "Company research and private-market data in one workspace.\n\nExplore companies, funds and private-market opportunities.\n\n#{links.join(' · ')}",
    category: products.id, tags: %w[svdex finance], skip_validations: true, skip_jobs: true)
end
[User.find_by!(username: "svdex-company"), fund, person].each do |entity|
  discovery = DiscourseSvdex::Discoveries.capture!(entity, listed_at: nil)
  next if discovery.contributor_user_id
  DiscourseSvdex::Discoveries.record!(entity, actor, provenance: "discovered", status: "accepted", contributor: actor.username,
    listed_at: discovery.listed_at&.iso8601 || Time.current.utc.iso8601, reason: "Reviewed initial directory entry and contributor provenance")
end
DirectoryItem.refresh_period!(:all)
raise "Staging isolation changed" unless SiteSetting.disable_emails == "yes" && SiteSetting.login_required && !SiteSetting.allow_new_registrations
puts "Isolated staging structure and content ready."
