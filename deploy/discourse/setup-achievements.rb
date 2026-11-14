# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

BadgeGrouping.transaction do
  position = [BadgeGrouping.minimum(:position).to_i - 1, 0].max
  group = BadgeGrouping.find_by(name: "SVDEX") || BadgeGrouping.find_by(name: "SVDX") || BadgeGrouping.new
  group.assign_attributes(name: "SVDEX", description: "SVDEX contributions and verification", position: group.persisted? ? group.position : position)
  group.save!

  badge = Badge.find_or_initialize_by(name: "Early Explorer")
  if badge.new_record?
    badge.assign_attributes(
      badge_grouping: group,
      badge_type_id: BadgeType::Bronze,
      description: "Helped shape SVDEX in its early days.",
      long_description: "Awarded by the team for exploring SVDEX and sharing thoughtful feedback during its early days.",
      icon: "certificate",
      enabled: true, listable: true, allow_title: false, multiple_grant: false,
      auto_revoke: false, target_posts: false, show_posts: false,
      trigger: Badge::Trigger::None,
    )
    badge.save!
  end
  if badge.badge_grouping_id == group.id
    [:description, :long_description].each do |field|
      badge[field] = badge[field]&.gsub("SVDX", "SVDEX")
    end
    badge.save! if badge.changed?
  end
  badge.update!(icon: "compass")
  raise "Badge belongs to another group" unless badge.badge_grouping_id == group.id
  verified = Badge.find_or_initialize_by(name: "Verified Accredited Investor")
  if verified.new_record?
    verified.assign_attributes(
      badge_grouping: group,
      badge_type_id: BadgeType::Silver,
      description: "Accredited-investor verification reviewed by SVDEX.",
      long_description: "Awarded manually by the SVDEX team after reviewing accredited-investor verification.",
      icon: "certificate",
      enabled: true, listable: true, allow_title: false, multiple_grant: false,
      auto_revoke: false, target_posts: false, show_posts: false,
      trigger: Badge::Trigger::None,
    )
    verified.save!
  end
  verified.update!(icon: "shield-halved")
  raise "Verification badge belongs to another group" unless verified.badge_grouping_id == group.id
  raise "Verification badge must be manually awarded" unless verified.trigger == Badge::Trigger::None && verified.query.blank?
  puts "#{group.name}: #{verified.name} (public, manual award, #{verified.grant_count} grants)"
  private_access = Badge.find_or_initialize_by(name: "Private Access")
  private_access.assign_attributes(
    badge_grouping: group, badge_type_id: BadgeType::Silver,
    description: "Invited to the private deals area.",
    long_description: "Granted when the SVDEX team adds a member to the private offerings group. Removed when that membership ends. Access is controlled by group membership, not this achievement.",
    icon: "key", enabled: true, listable: true, allow_title: false, multiple_grant: false,
    auto_revoke: false, target_posts: false, show_posts: false, trigger: Badge::Trigger::None,
  )
  private_access.save!
  raise "Group must precede Getting Started" unless group.position < BadgeGrouping.find(BadgeGrouping::GettingStarted).position
  puts "#{group.name}: #{badge.name} (manual award, #{badge.grant_count} grants)"
end
