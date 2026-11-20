# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_products_category_id)
presales = Category.find(SiteSetting.svdex_presales_category_id)
raise "Pre-sales must be a public Products subcategory" unless presales.parent_category_id == category.id && !presales.read_restricted
actor = User.find_by!(username: "svdex")
raise "Products must remain public with normal replies" unless !category.read_restricted && category.reply_posting_review_mode == "no_one"
raise "Products are classified as offerings" if DiscourseSvdex.offering_category?(category.id)
Post.transaction do
  member = User.create!(username: "product_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2)
  title = "Research workspace #{SecureRandom.hex(5)}"
  submission = NewPostManager.new(member, title: "Suggested product #{SecureRandom.hex(5)}", category: category.id,
    raw: "A product that a member submitted for review from the website.", skip_jobs: true).perform
  raise "Native product submissions bypass review" unless submission.success? && submission.reviewable
  raise "Staff catalog publishing is blocked" unless actor.guardian.can_create_topic_on_category?(category)
  post = PostCreator.create!(actor, title: title, raw: "Research tools for company analysis.\n\n[Company profile](/u/svdex-company/summary)", category: category.id, skip_validations: true, skip_jobs: true)
  topic = post.topic.reload
  campaign = PostCreator.create!(actor, title: "Research early access #{SecureRandom.hex(5)}", raw: "Early access to the research workspace, with delivery and purchase terms in this campaign.",
    category: presales.id, svdex_presale_product_id: topic.id, svdex_presale_summary: "Research early access campaign", svdex_presale_price: "$120 per year", skip_validations: true, skip_jobs: true).topic
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
  directory = DiscourseSvdex::ProductDirectory.new(search: topic.title).payload.fetch(:products)
  raise "Campaign did not update the canonical product stage" unless directory.map { |row| row.values_at(:id, :stage) } == [[topic.id, "presale"]]
  filtered_directory = DiscourseSvdex::ProductDirectory.new(stage: "presale").payload.fetch(:products)
  raise "Pre-sale product filter included an inactive product" unless filtered_directory.all? { |row| row[:stage] == "presale" }
  linked = filtered_directory.find { |row| row[:id] == topic.id }
  raise "Pre-sale product lost its campaign link" unless linked&.fetch(:campaign_url) == campaign.relative_url
  item = TopicListItemSerializer.new(topic, scope: guest, root: false).as_json
  raise "Guest preview missing" unless item[:svdex_product][:summary].include?("Research tools")
  raise "Product became a campaign" if item.key?(:svdex_listing) || item.key?(:svdex_presale) || DiscourseSvdex.listing?(topic)
  view = TopicViewSerializer.new(TopicView.new(topic.id, nil), scope: guest, root: false).as_json
  raise "Native body missing" unless view[:post_stream][:posts].first[:cooked].include?("Company profile")
  reply = NewPostManager.new(member, topic_id: topic.id, raw: "Can the workspace export the research into a spreadsheet?", skip_jobs: true).perform
  raise "Product replies must use normal behavior" unless reply.success? && reply.action == :create_post
  like = PostActionType.types[:like]
  raise "Native product vote failed" unless PostActionCreator.new(member, topic.first_post, like).perform.success?
  raise "Native reply like failed" unless PostActionCreator.new(actor, reply.post, like).perform.success?
  directory_vote = DiscourseSvdex::ProductDirectory.new({ search: topic.title }, Guardian.new(member)).payload.fetch(:products).first.fetch(:vote)
  raise "Directory vote counted reply likes or lost the member's vote" unless directory_vote.values_at(:count, :voted) == [1, true]
  list_vote = TopicListItemSerializer.new(topic.reload, scope: Guardian.new(member), root: false).as_json.fetch(:svdex_product).fetch(:vote)
  raise "Product list and directory votes differ" unless list_vote == directory_vote
  raise "Native vote withdrawal failed" unless PostActionDestroyer.new(member, topic.first_post, like).perform.success?
  raise "Withdrawn vote still counts" unless DiscourseSvdex::Products.votes_for([topic.reload], Guardian.new(member)).fetch(topic.id).values_at(:count, :voted) == [0, false]
  raise "Native edit failed" unless PostRevisor.new(post).revise!(actor, { raw: "Updated research tools for company analysis.\n\n[Company profile](/u/svdex-company/summary)" })
  updated = TopicListItemSerializer.new(topic.reload, scope: guest, root: false).as_json
  raise "Description did not update" unless updated[:svdex_product][:summary].include?("Updated research")
  raise "Company connection changed" unless topic.category_id == category.id
puts "PASS Products queue native member submissions for review and retain public topics, editable descriptions and member replies"
  puts "PASS native Products list combines campaigns; regular-only and pre-sale-only routes filter before pagination and omit category description topics"
  raise ActiveRecord::Rollback
end
