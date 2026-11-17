# frozen_string_literal: true
# Public classification only: no accounts created and no ownership transferred.
local = GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
staging = GlobalSetting.hostname == "staging.svdex.com" && ENV["SVDEX_STAGING_SETUP"] == "1" && SiteSetting.disable_emails == "yes" && SiteSetting.login_required && !SiteSetting.allow_new_registrations
production = GlobalSetting.hostname == "svdex.com"
explicit = ENV["SVDEX_CONFIGURE_UPGRADE"] == "1" || ENV["SVDEX_INITIAL_SETUP"] == "1"
abort "Explicit People setup required" unless local || ((production || staging) && explicit)
Group.transaction do
  if [SiteSetting.svdex_people_group_name, SiteSetting.svdex_companies_group_name, SiteSetting.svdex_funds_group_name].include?(SiteSetting.svdex_maintained_accounts_group_name)
    raise "Management and catalog groups must be separate"
  end
  maintained = Group.find_or_initialize_by(name: SiteSetting.svdex_maintained_accounts_group_name)
  raise "Account management marker must be a manual group" if maintained.automatic?
  if maintained.persisted? && maintained.group_users.joins(:user).where(owner: true, users: { admin: false, moderator: false }).exists?
    raise "Account management classification must be staff-managed"
  end
  maintained.assign_attributes(full_name: "SVDEX-maintained profiles", visibility_level: Group.visibility_levels[:staff],
    members_visibility_level: Group.visibility_levels[:staff], public_admission: false, public_exit: false,
    allow_membership_requests: false)
  maintained.save!
  group = Group.find_or_initialize_by(name: SiteSetting.svdex_people_group_name)
  raise "People group must be a manual group" if group.automatic?
  if group.persisted? && group.group_users.joins(:user).where(owner: true, users: { admin: false, moderator: false }).exists?
    raise "People membership must be managed by staff"
  end
  group.assign_attributes(full_name: "People", visibility_level: Group.visibility_levels[:public],
    members_visibility_level: Group.visibility_levels[:public], public_admission: false,
    public_exit: false, allow_membership_requests: false)
  group.save!
  DiscourseSvdex::PeopleDirectory.configure_fields!
  TranslationOverride.upsert!("en", "js.directory.title", "Users")
  TranslationOverride.upsert!("en", "js.directory.total_rows.one", "%{count} user")
  TranslationOverride.upsert!("en", "js.directory.total_rows.other", "%{count} users")
end
puts "People directory configured; membership stays staff-curated. Users includes independently managed accounts of every type."
