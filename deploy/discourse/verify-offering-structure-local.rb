# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
def assert_structure!(ok, message)
  raise message unless ok
  puts "PASS #{message}"
end
parent = Category.find(SiteSetting.svdex_listings_category_id)
public_category = Category.find(SiteSetting.svdex_public_offerings_category_id)
private_category = Category.find(SiteSetting.svdex_private_offerings_category_id)
assert_structure!(public_category.name == "Public offerings" && private_category.name == "Private offerings", "offering children use approved names")
assert_structure!([public_category, private_category].all? { |c| c.parent_category_id == parent.id }, "both offering categories are children of the combined parent")
assert_structure!(!public_category.read_restricted? && private_category.read_restricted?, "visibility remains enforced by native category permissions")
assert_structure!(!Topic.where(category_id: parent.id).where.not(id: parent.topic_id).exists?, "existing public offerings moved out of the parent without duplicates")
assert_structure!(SiteSetting.default_subcategory_on_read_only_category, "native New Topic falls back to a writable child")
actor = User.find_by!(username: "svdex")
User.transaction do
  member = User.create!(username: "structure_#{SecureRandom.hex(3)}", email: "#{SecureRandom.hex(10)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2)
  assert_structure!(!member.guardian.can_create_topic_on_category?(parent) && member.guardian.can_create_topic_on_category?(public_category), "ordinary members post in the public child, not its container")
  public_topic, private_topic = [public_category, private_category].map do |category|
    PostCreator.create!(actor, title: "Structured offering #{SecureRandom.hex(5)}", raw: "Offering structure and access verification content.", category: category.id, tags: %w[svdex finance], skip_validations: true, skip_jobs: true).topic
  end
  assert_structure!(public_topic.tags.pluck(:name).include?("public-offering") && private_topic.tags.pluck(:name).include?("private-offering"), "visibility tags are added automatically to new offering topics")
  assert_structure!(!public_topic.tags.where(name: %w[506b 506c 4a7]).exists? && !private_topic.tags.where(name: %w[506b 506c 4a7]).exists?, "category placement never invents a legal exemption classification")
  assert_structure!(DiscourseTagging.tag_topic_by_names(private_topic, actor.guardian, %w[svdex finance private-offering 506b]), "staff can record one reviewed exemption tag")
  assert_structure!(!DiscourseTagging.tag_topic_by_names(public_topic, member.guardian, %w[svdex finance public-offering 506c]), "native tag-group permissions prevent unreviewed member exemption claims")
  public_topic.errors.clear
  assert_structure!(DiscourseTagging.tag_topic_by_names(public_topic, actor.guardian, %w[svdex finance]), "staff topic editing remains available")
  assert_structure!(public_topic.tags.reload.pluck(:name).include?("public-offering"), "visibility label cannot become stale when tags are edited")
  [nil, member, actor].each do |viewer|
    ids = TopicQuery.new(viewer, category: parent.id, per_page: 100).list_latest.topics.map(&:id)
    assert_structure!(ids.include?(public_topic.id) && ids.include?(private_topic.id) == (viewer == actor), "combined parent respects #{viewer == actor ? 'staff' : viewer ? 'member' : 'guest'} topic access")
    home_ids = TopicQuery.new(viewer, per_page: 100).list_latest.topics.map(&:id)
    assert_structure!(home_ids.include?(public_topic.id) && home_ids.include?(private_topic.id) == (viewer == actor), "Home recognizes both children without bypassing native security")
  end
  private_topic.change_category_to_id(public_category.id, silent: true)
  assert_structure!((private_topic.tags.reload.pluck(:name) & %w[public-offering private-offering]) == ["public-offering"], "an authorized category move replaces the visibility label")
  private_topic.change_category_to_id(private_category.id, silent: true)
  assert_structure!((private_topic.tags.reload.pluck(:name) & %w[public-offering private-offering]) == ["private-offering"], "moving back to the restricted category restores the private label")
  public_topic.change_category_to_id(Category.find_by!(slug: "discussion").id, silent: true)
  assert_structure!(!public_topic.tags.reload.where(name: %w[public-offering private-offering]).exists?, "moving out of Offerings removes the derived visibility label")
  raise ActiveRecord::Rollback
end
puts "Offering structure checks complete; all test records rolled back."
