# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_products_category_id)
presales = Category.find(SiteSetting.svdex_presales_category_id)
raise "Pre-sales must be a public Products subcategory" unless presales.parent_category_id == category.id && !presales.read_restricted
actor = User.find_by!(username: "svdex")
raise "Products must remain a public reviewed category" unless !category.read_restricted && category.topic_posting_review_mode == "everyone" && category.reply_posting_review_mode == "no_one"
raise "Products mixed with financing feeds" if DiscourseSvdex.offering_category?(category.id) || DiscourseSvdex.home_category_ids.include?(category.id)
Post.transaction do
  member = User.create!(username: "product_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2)
  title = "Research workspace #{SecureRandom.hex(5)}"
  result = NewPostManager.new(member, title: title, raw: "Research tools for company analysis.\n\n[Company profile](/u/svdex-company/summary)", category: category.id).perform
  raise "Product not queued: #{result.errors.full_messages}" unless result.success? && result.action == :enqueued
  raise "Unreviewed product published" if Topic.exists?(title: title)
  approved = result.reviewable.perform(actor, :approve_post)
  raise "Product approval failed" unless approved.success?
  post = approved.created_post
  topic = post.topic.reload
  campaign = PostCreator.create!(actor, title: "Research early access #{SecureRandom.hex(5)}", raw: "Early access to the research workspace, with delivery and purchase terms in this campaign.",
    category: presales.id, svdex_presale_summary: "Research early access campaign", svdex_presale_price: "$120 per year", skip_validations: true, skip_jobs: true).topic
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  paths = {
    "#{category.url}/l/latest.json" => [topic.id, campaign.id],
    "#{category.url}/none/l/latest.json" => [topic.id],
    "#{presales.url}/l/latest.json" => [campaign.id],
  }
  paths.each do |path, expected|
    app.get path
    raise "Product filter route failed: #{path}" unless app.response.status == 200
    rows = app.response.parsed_body.fetch("topic_list").fetch("topics")
    ids = rows.map { |row| row.fetch("id") }
    actual = ids & [topic.id, campaign.id]
    raise "Product type filter ignored: #{path}" unless actual.sort == expected.sort
    raise "Category description shown as product" if (ids & [category.topic_id, presales.topic_id]).any?
    raise "Product feed includes another category" if rows.any? { |row| ![category.id, presales.id].include?(row["category_id"]) }
  end
  guest = Guardian.new
  guest.ensure_can_see!(topic)
  item = TopicListItemSerializer.new(topic, scope: guest, root: false).as_json
  raise "Guest preview missing" unless item[:svdex_product][:summary].include?("Research tools")
  raise "Product became a campaign" if item.key?(:svdex_listing) || item.key?(:svdex_presale) || DiscourseSvdex.listing?(topic)
  view = TopicViewSerializer.new(TopicView.new(topic.id, nil), scope: guest, root: false).as_json
  raise "Native body missing" unless view[:post_stream][:posts].first[:cooked].include?("Company profile")
  reply = NewPostManager.new(member, topic_id: topic.id, raw: "Can the workspace export the research into a spreadsheet?", skip_jobs: true).perform
  raise "Product replies must use normal behavior" unless reply.success? && reply.action == :create_post
  raise "Native edit failed" unless PostRevisor.new(post).revise!(member, { raw: "Updated research tools for company analysis.\n\n[Company profile](/u/svdex-company/summary)" })
  updated = TopicListItemSerializer.new(topic.reload, scope: guest, root: false).as_json
  raise "Description did not update" unless updated[:svdex_product][:summary].include?("Updated research")
  raise "Company connection changed" unless topic.category_id == category.id
  puts "PASS products use public native topics, reviewed submissions, editable descriptions, links and replies without financial records or Home feed inclusion"
  puts "PASS native Products list combines campaigns; regular-only and pre-sale-only routes filter before pagination and omit category description topics"
  raise ActiveRecord::Rollback
end
