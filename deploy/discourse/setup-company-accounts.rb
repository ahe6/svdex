# frozen_string_literal: true
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
actor = User.find_by!(username: "svdex")
group = Group.find_by(name: SiteSetting.svdex_companies_group_name) || Group.create!(
  name: SiteSetting.svdex_companies_group_name, full_name: "Companies",
  visibility_level: Group.visibility_levels[:public], members_visibility_level: Group.visibility_levels[:public],
)
# Membership is staff-managed classification, never a trust level or offering permission.
group.update!(public_admission: false, public_exit: false, allow_membership_requests: false)
funds = Group.find_by(name: SiteSetting.svdex_funds_group_name) || Group.create!(
  name: SiteSetting.svdex_funds_group_name, full_name: "Funds",
  visibility_level: Group.visibility_levels[:public], members_visibility_level: Group.visibility_levels[:public],
)
funds.update!(public_admission: false, public_exit: false, allow_membership_requests: false)
# A fresh clone must not depend on accounts created by earlier manual UI work.
# These guarded local fixtures never run through the production release path.
User.transaction do
  {
    "svdex-company" => ["SVDEX", "svdex", "Company discovery, discussion and private-capital opportunities."],
    "northstar" => ["Northstar Instruments", "northstar", "Compact optical instruments for the next generation of research labs."],
  }.each do |username, (name, tag_name, description)|
    user = User.find_by(username: username)
    created = user.nil?
    if user && (user.staff? || !group.users.exists?(id: user.id))
      raise "Existing account is not a classified local company fixture"
    end
    user ||= User.create!(username: username, name: name, email: "#{username}@example.invalid",
      password: SecureRandom.hex(32), active: true, approved: true, trust_level: 1)
    group.add(user) unless group.users.exists?(id: user.id)
    Group.find_by(name: SiteSetting.svdex_maintained_accounts_group_name)&.add(user)
    user.email_tokens.update_all(confirmed: true) if created
    user.user_profile.update!(bio_raw: description) if user.user_profile.bio_raw.blank?
    user.custom_fields["svdex_company_tag_id"] ||= Tag.find_by!(name: tag_name).id.to_s
    user.save_custom_fields
  end
end
accounts = User.where(username: %w[svdex-company northstar]).index_by(&:id)
accounts.each_value { |user| group.add(user) unless group.users.exists?(id: user.id) }

category = Category.find_by(slug: "companies")
if category
  topics = Topic.with_deleted.where(category_id: category.id).where.not(id: category.topic_id).to_a
  snapshot = { category: category.attributes, topics: topics.map { |topic| { attributes: topic.attributes, fields: topic.custom_fields, posts: Post.with_deleted.where(topic_id: topic.id).map(&:attributes) } } }
  File.write("/tmp/svdex-company-topics-before.json", JSON.pretty_generate(snapshot), perm: 0o600)
  Category.transaction do
    topics.each do |topic|
      user = accounts[topic.first_post.user_id]
      raise "Unexpected company profile owner" unless user
      # Preserve previously entered company facts on the actual account. A cap
      # remains an offering term and is never treated as company valuation.
      DiscourseSvdex::FIELDS.keys.each do |key|
        value = topic.custom_fields[key]
        user.custom_fields[key] = value if value.present? && user.custom_fields[key].blank?
      end
      company_group = TagGroup.find_by_name_insensitive("Companies")
      tag = topic.tags.find { |item| company_group.tags.exists?(id: item.id) }
      user.custom_fields["svdex_company_tag_id"] = tag.id.to_s if tag
      user.save_custom_fields
      profile = user.user_profile
      profile.update!(bio_raw: topic.custom_fields["svdex_summary"]) if profile.bio_raw.blank?
      # Preserve the mistakenly created topic content in a recoverable staff
      # archive, then remove the now-empty category from the product structure.
      raise "Could not archive old company topic" unless topic.change_category_to_id(Category.find_by!(slug: "staff").id, silent: true)
      PostDestroyer.new(actor, topic.first_post).destroy unless topic.deleted_at
    end
    CategoryDestroyer.destroy(actor.guardian, category.reload)
  end
end
SiteSetting.where(name: "svdex_companies_category_id").delete_all
SiteSetting.default_navigation_menu_categories = [SiteSetting.svdex_listings_category_id, Category.find_by!(slug: "discussion").id].join("|")
puts "Companies directory: /companies; company accounts: #{group.users.order(:username).pluck(:username).join(', ')}"
