# frozen_string_literal: true
local = GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
abort "Explicit SVDEX page retirement required" unless local || (GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_RETIRE_INFORMATION_PAGES"] == "1")
raise "Install the updated page routes first" unless defined?(DiscourseSvdex::RetiredGuidelinesPages)
actor = local ? User.find_by!(username: "svdex") : User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
raise "Active administrator required" unless actor&.admin? && actor.active?
ActiveRecord::Base.transaction do
  section = SidebarSection.find_by!(section_type: :community, public: true)
  section.sidebar_urls.where(value: %w[/about /faq /guidelines /rules /conduct]).each do |url|
    section.sidebar_section_links.where(linkable: url).destroy_all
  end
  Topic.find_by(id: SiteSetting.guidelines_topic_id)&.update!(visible: false, archived: true)
  Badge.find_by(id: Badge::ReadGuidelines)&.update!(enabled: false, listable: false)
  welcome = Topic.find_by(slug: "welcome-to-svdex", user_id: Discourse.system_user.id)&.first_post
  if welcome
    raw = welcome.raw.gsub(/Before replying or starting new topics, please review the \[(?:Community )?Guidelines\]\(\/(?:faq|guidelines)\)\.?/, "")
    raw = raw.gsub(/\[(?:Community )?Guidelines\]\(\/(?:faq|guidelines)\)/, "the site terms")
    raw = raw.gsub(/\[contact the admins\]\(\/about\)/i, "[email us](mailto:austin@svdex.com)")
    if raw != welcome.raw
      raise "Could not remove obsolete Welcome links" unless PostRevisor.new(welcome).revise!(actor, { raw: raw }, skip_validations: true, bypass_bump: true)
    end
  end
end
puts "Retired About and Guidelines discovery; preserved staff records and award history."
