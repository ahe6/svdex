# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def assert!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end
parent = Category.find(SiteSetting.svdex_listings_category_id)
category = Category.find(SiteSetting.svdex_private_offerings_category_id)
group = Group.find_by!(name: SiteSetting.svdex_private_offerings_group_name)
badge = Badge.find_by!(name: "Private Access")
assert!(category.parent_category_id == parent.id && category.read_restricted?, "private offerings is a secured child category")
assert!(!group.public_admission && !group.allow_membership_requests, "private membership is invitation-only")
assert!(category.topic_posting_review_mode == parent.topic_posting_review_mode, "private offerings preserve topic review")

User.transaction do
  create_user = -> { User.create!(username: "private_check_#{SecureRandom.hex(3)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 1) }
  member, outsider = create_user.call, create_user.call
  group.add(member)
  assert!(UserBadge.exists?(user: member, badge: badge), "private access achievement follows group invitation")
  assert!(!outsider.guardian.can_see?(category) && !Guardian.new.can_see?(category) && member.guardian.can_see?(category), "only invited members and staff can see the private category")
  public_tag = Tag.find_by!(name: "svdex")
  title = "Restricted offering #{SecureRandom.hex(4)} — Note"
  topic = PostCreator.create!(Discourse.system_user, title: title, raw: "Company development and privately shared offering terms for invited members.", category: category.id, tags: [public_tag.name, "finance"], skip_validations: true, skip_jobs: true,
    svdex_summary: "Private capital for business development", svdex_interest_rate: "8% annually", svdex_post_money_valuation_usd: "10000000").topic
  assert!(topic.custom_fields["svdex_interest_rate"] == "8% annually" && DiscourseSvdex.listing?(topic), "private topics preserve structured offering fields")
  [nil, outsider, member].each do |viewer|
    visible = viewer == member
    guardian = Guardian.new(viewer)
    ids = TopicQuery.new(viewer, per_page: 100, category: parent.id).list_latest.topics.map(&:id)
    assert!(ids.include?(topic.id) == visible, "combined Offerings feed respects #{viewer == member ? 'invited' : viewer ? 'ordinary member' : 'guest'} visibility")
    assert!(DiscourseSvdex::CompanyDirectory.offering_scope(guardian).exists?(id: topic.id) == visible, "company counts and profiles use the same permitted offering scope")
    result = TopicListItemSerializer.new(topic, scope: guardian, root: false).as_json if visible
    assert!(result.deep_stringify_keys["svdex_listing"]["interest_rate"] == "8% annually", "authorized private offering serializes financial content") if visible
  end
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.get "/private-offerings"
  assert!(app.response.status == 200, "public private-access information page is accessible without membership")
  app.get "/private-offerings/summary.json"
  summary = app.response.parsed_body
  assert!(app.response.status == 200 && summary == {}, "public discovery never exposes private offering counts or activity")
  app.get "/categories.json"
  assert!(app.response.parsed_body["category_list"]["categories"].none? { |row| row["id"] == category.id }, "public information entry does not expose restricted category records")
  app.get "#{parent.url}.json", params: { svdex_company: title.split(" — ").first }
  assert!(app.response.status == 200 && JSON.parse(app.response.body)["topic_list"]["topics"].empty?, "guest combined filters never expose private-only offerings")
  app.get "/listings/companies.json", params: { q: title.split(" — ").first }
  assert!(JSON.parse(app.response.body)["companies"].empty?, "private issuer names do not leak through guest autocomplete")
  app.get "#{category.url}.json"
  assert!([403, 404].include?(app.response.status), "guest direct category URL is protected")
  app.get "/t/#{topic.id}.json"
  assert!([403, 404].include?(app.response.status), "guest direct private topic URL is protected")
  queued = NewPostManager.new(member, title: "New private offering #{SecureRandom.hex(4)}", raw: "Private offering submission for staff review and approval before publication.", category: category.id, tags: [public_tag.name, "finance"], svdex_summary: "Review required for private offerings").perform
  assert!(queued.success? && queued.action == :enqueued, "invited members' new private offerings require review")
  group.remove(member)
  assert!(!UserBadge.exists?(user: member, badge: badge), "membership removal revokes the access achievement")
  assert!(!Guardian.new(member.reload).can_see?(topic.reload), "membership removal revokes private topic access")
  # A manually awarded achievement must never grant category access.
  BadgeGranter.grant(badge, outsider)
  assert!(!Guardian.new(outsider.reload).can_see?(category), "badge ownership alone never grants private access")
  raise ActiveRecord::Rollback
end
