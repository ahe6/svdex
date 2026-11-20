# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
help = Category.find(SiteSetting.svdex_help_category_id)
discussion = Category.find_by!(slug: "discussion")
raise "Help is restricted or muted by default" if help.read_restricted? || SiteSetting.default_categories_muted.split("|").include?(help.id.to_s)
raise "Help is not the native feedback category" unless SiteSetting.meta_category_id.to_i == help.id

Post.transaction do
  member = User.create!(username: "help_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid",
    password: SecureRandom.hex(24), active: true, approved: true, trust_level: 1)
  tag = Tag.create!(name: "helpcheck#{SecureRandom.hex(4)}")
  create_topic = lambda do |category, fields = {}|
    post = PostCreator.create!(Discourse.system_user, title: "Support check #{SecureRandom.hex(6)}",
      raw: "Transaction-scoped feed visibility check.", category: category.id, skip_validations: true, skip_jobs: true, **fields)
    post.topic.tags << tag
    TopTopic.create!(topic_id: post.topic_id, all_score: 100_000, daily_score: 100_000)
    post.topic
  end
  support = create_topic.call(help)
  control = create_topic.call(Category.find(SiteSetting.svdex_listings_category_id))
  conversation = create_topic.call(discussion)
  restricted = create_topic.call(Category.find(SiteSetting.svdex_private_offerings_category_id))
  product = create_topic.call(Category.find(SiteSetting.svdex_products_category_id))
  presale = create_topic.call(Category.find(SiteSetting.svdex_presales_category_id), { svdex_presale_product_id: product.id })
  event = create_topic.call(Category.find(SiteSetting.svdex_events_category_id))
  expected_home = [control, conversation, product, presale, event].map(&:id)
  support.update!(pinned_at: Time.now, pinned_globally: true)
  CategoryUser.set_notification_level_for_category(member, CategoryUser.notification_levels[:watching], help.id)
  TopicUser.change(member.id, support.id, notification_level: TopicUser.notification_levels[:watching])

  [nil, member, User.find_by!(username: "svdex")].each do |user|
    ids = ->(list) { list.topics.map(&:id) }
    query = ->(opts = {}) { TopicQuery.new(user, { per_page: 100 }.merge(opts)) }
    [:latest, :top].each do |filter|
      list = ->(q) { filter == :latest ? q.list_latest : q.list_top_for(:all) }
      global = ids.call(list.call(query.call))
      raise "Feedback leaked into global #{filter}" if global.include?(support.id)
      raise "Public topics missing from global #{filter}" unless (expected_home - global).empty?
      raise "Private offering leaked into Home" if !Guardian.new(user).can_see?(restricted) && global.include?(restricted.id)
      category_ids = ids.call(list.call(query.call(category: help.id)))
      raise "Direct Help #{filter} lost support post" unless category_ids.include?(support.id)
      tag_ids = ids.call(list.call(query.call(tags: [tag.name])))
      raise "Tag #{filter} lost support post" unless tag_ids.include?(support.id)
      home_tag_ids = ids.call(list.call(query.call(tags: [tag.name], svdex_home: "1")))
      raise "Home tag #{filter} included Feedback" if home_tag_ids.include?(support.id)
      raise "Home tag #{filter} lost matching public topics" unless (expected_home - home_tag_ids).empty?
      raise "Home tag #{filter} bypassed private permissions" if !Guardian.new(user).can_see?(restricted) && home_tag_ids.include?(restricted.id)
    end
    raise "Direct topic access lost" unless TopicView.new(support.id, user).topic.id == support.id
  end
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  ["/latest.json", "/top.json?period=all", "/categories_and_latest.json"].each do |path|
    app.get path
    raise "HTTP #{app.response.status} for #{path}" unless app.response.status == 200
    topic_ids = app.response.parsed_body.fetch("topic_list").fetch("topics").map { |topic| topic.fetch("id") }
    raise "Help leaked into #{path}" if topic_ids.include?(support.id)
    raise "Positive control absent from #{path}" unless topic_ids.include?(control.id)
  end
  ["/latest.json", "/top.json?period=all"].each do |path|
    app.get path, params: {tags: tag.name, svdex_home: "1"}
    raise "Home tag HTTP #{app.response.status}" unless app.response.status == 200
    visible_ids = app.response.parsed_body.fetch("topic_list").fetch("topics").map { |topic| topic.fetch("id") }
    raise "Tagged Home exposed Feedback or private offerings" if (visible_ids & [support.id, restricted.id]).any?
    raise "Tagged Home lost matching topics" unless (expected_home - visible_ids).empty?
  end
  puts "PASS Home shows products, pre-sales, offerings, events and discussions, including with tag filters; Feedback and private permissions hold"
  app.get "#{help.url}.json"
  raise "Help directory unavailable" unless app.response.status == 200 && app.response.parsed_body.fetch("topic_list").fetch("topics").any? { |topic| topic["id"] == support.id }
  SearchIndexer.index(support.first_post, force: true)
  app.get "/search.json", params: { q: "#{support.title} in:title" }
  raise "Search unavailable" unless app.response.status == 200
  raise "Help disappeared from search" unless app.response.parsed_body.fetch("topics", []).any? { |topic| topic["id"] == support.id }
  raise "Watching preference changed" unless CategoryUser.find_by!(user_id: member.id, category_id: help.id).notification_level == CategoryUser.notification_levels[:watching]
  puts "PASS global Latest/Top/Overview exclude pinned/watched Help for guests, members and staff; direct category/tag feeds, topic access, search and notification preferences remain native"
  raise ActiveRecord::Rollback
end
