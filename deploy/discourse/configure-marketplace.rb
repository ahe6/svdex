# frozen_string_literal: true
# Reviewed native configuration only; no local financial fixtures are imported.
local = GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
production = GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_CONFIGURE_MARKETPLACE"] == "1"
staging = GlobalSetting.hostname == "staging.svdex.com" && ENV["SVDEX_STAGING_SETUP"] == "1" && SiteSetting.disable_emails == "yes" && SiteSetting.login_required && !SiteSetting.allow_new_registrations
abort "Local setup or explicit deployment configuration required" unless local || production || staging
actor = local ? User.find_by!(username: "svdex") : User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Active administrator required" unless actor&.admin? && actor.active?
ActiveRecord::Base.transaction do
  category = Category.find_by(id: SiteSetting.svdex_introductions_category_id) || Category.find_by(slug: "company-updates") || Category.find_by(slug: "introductions") || Category.new(user: actor)
  raise "Unexpected updates category" if category.persisted? && !%w[introductions company-updates].include?(category.slug)
  category.assign_attributes(name: "Company & Fund Updates", slug: "company-updates", color: "2396BF", text_color: "FFFFFF")
  category.set_permissions("everyone" => :create_post, SiteSetting.svdex_companies_group_name => :full, "staff" => :full)
  category.save!
  category.update!(topic_posting_review_mode: "everyone", reply_posting_review_mode: "no_one",
    description: "Official company and fund introductions, milestones and business updates. Approved organizations and authorized staff can submit updates; everyone can join the discussion.")
  SiteSetting.svdex_introductions_category_id = category.id
  events = Category.find_by(id: SiteSetting.svdex_events_category_id) || Category.find_by(slug: "events") || Category.new(user: actor)
  events.assign_attributes(name: "Events", slug: "events", color: "E45735", text_color: "FFFFFF")
  events.set_permissions("everyone" => :full)
  events.save!
  events.update!(description: "Community calls, company presentations and conversations about private markets.")
  SiteSetting.svdex_events_category_id = events.id
  SiteSetting.calendar_upcoming_events_default_category = events.id
  raise "Updates must remain public" if category.read_restricted?
  group = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
  # Native membership requests require an owner. A staff owner manages requests
  # but is not an organization account and is excluded from organization rows.
  group.add(actor) unless group.users.exists?(actor.id)
  group.add_owner(actor) unless group.group_users.exists?(user: actor, owner: true)
  group.update!(public_admission: false, public_exit: false, allow_membership_requests: true,
    membership_request_template: "Apply as a company using the company application form. Staff review every request before approval.")
  SiteSetting.svdex_private_access_form_url = staging ? "" : "https://tally.so/r/xVM7or"
  private_group = Group.find_by(name: SiteSetting.svdex_private_offerings_group_name)
  private_group&.update!(full_name: "Private Deals members")
  access_badge = Badge.find_by(name: "Private Access")
  if access_badge
    access_badge.update!(description: "Invited to the private deals area.", long_description: "Granted when the SVDEX team adds a member to the private deals group. Removed when that membership ends. Access is controlled by group membership, not this achievement.")
  end
  private_category = Category.find_by(id: SiteSetting.svdex_private_offerings_category_id)
  if private_category
    raise "Private category must stay restricted" unless private_category.read_restricted?
    private_category.update!(name: "Private offerings", description: "Access-restricted primary offerings and private secondary sale opportunities.")
  end
  DiscourseSvdex::OfferingStructure.configure!(actor)
end
if local
  SiteSetting.svdex_interest_enabled = true
  SiteSetting.svdex_interest_staff_preview = true
  SiteSetting.svdex_interest_public_totals = true
end
lounge = Chat::CategoryChannel.find_by(name: "Lounge")
if lounge && lounge.open? && !lounge.chatable.read_restricted?
  SiteSetting.svdex_lounge_channel_url = lounge.relative_url
end
DiscourseTagging.clear_cache!
puts "Configured marketplace, public/private offering children and visibility/exemption tags. Existing public topics moved through native category APIs; no financial facts or access grants created."
