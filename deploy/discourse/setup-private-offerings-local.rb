# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
parent = Category.find(SiteSetting.svdex_listings_category_id)
Group.transaction do
  group = Group.find_or_initialize_by(name: SiteSetting.svdex_private_offerings_group_name)
  group.assign_attributes(full_name: "Private Deals members", visibility_level: Group.visibility_levels[:members],
    members_visibility_level: Group.visibility_levels[:members], public_admission: false,
    public_exit: false, allow_membership_requests: false)
  group.save!
  category = Category.find_by(id: SiteSetting.svdex_private_offerings_category_id) || Category.find_by(slug: "private-offerings", parent_category_id: parent.id) || Category.new(user: Discourse.system_user)
  category.assign_attributes(name: "Private offerings", slug: "private-offerings", parent_category_id: parent.id,
    color: parent.color, text_color: parent.text_color,
    topic_posting_review_mode: parent.topic_posting_review_mode, reply_posting_review_mode: parent.reply_posting_review_mode,
    minimum_required_tags: parent.minimum_required_tags)
  category.set_permissions(group.name => :full, "staff" => :full)
  category.save!
  category.reload.update!(topic_posting_review_mode: parent.topic_posting_review_mode, reply_posting_review_mode: parent.reply_posting_review_mode)
  category.update!(description: "Access-restricted primary offerings and private secondary sale opportunities.")
  SiteSetting.svdex_private_offerings_category_id = category.id
  badge = Badge.find_by!(name: "Private Access")
  group.users.find_each { |user| BadgeGranter.grant(badge, user) }
  puts "Private offerings configured as a secured child of Offerings. No members added."
end
DiscourseSvdex::OfferingStructure.configure!(User.find_by!(username: "svdex"))
