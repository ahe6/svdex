# frozen_string_literal: true
# Existing classifications have no trustworthy discovery date or contributor.
# Preserve that uncertainty; never award seed/import activity retroactively.
local = GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
staging = GlobalSetting.hostname == "staging.svdex.com" && ENV["SVDEX_STAGING_SETUP"] == "1" && SiteSetting.disable_emails == "yes" && SiteSetting.login_required && !SiteSetting.allow_new_registrations
explicit = ENV["SVDEX_CONFIGURE_UPGRADE"] == "1" || ENV["SVDEX_INITIAL_SETUP"] == "1"
abort "Explicit discovery setup required" unless local || ((GlobalSetting.hostname == "svdex.com" || staging) && explicit)
ids = GroupUser.where(group_id: Group.where(name: [SiteSetting.svdex_companies_group_name, SiteSetting.svdex_funds_group_name, SiteSetting.svdex_people_group_name]).select(:id)).select(:user_id)
User.where(id: ids).find_each { |user| DiscourseSvdex::Discoveries.capture!(user, listed_at: nil) }
puts "Discovery provenance initialized without invented dates or personal credit."
