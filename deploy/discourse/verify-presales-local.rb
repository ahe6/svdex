# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_presales_category_id)
raise "Product category is a securities category" if DiscourseSvdex.offering_category?(category.id)
raise "Public product category requires review" unless !category.read_restricted && category.topic_posting_review_mode == "everyone" && category.reply_posting_review_mode == "no_one"
actor = User.find_by!(username: "svdex")
DiscourseSvdex::Prototypes::CompanyProfiles.setup!
Post.transaction do
  user = User.create!(username: "presale_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2)
  product = PostCreator.create!(actor, title: "Research product #{SecureRandom.hex(5)}", raw: "An optical instrument for doing research in the field.", category: SiteSetting.svdex_products_category_id, skip_validations: true, skip_jobs: true).topic
  company_tag = Tag.create!(name: "research-company-#{SecureRandom.hex(5)}")
  product.tags << company_tag
  logo = Upload.where(secure: false).first!
  DiscourseSvdex::Prototypes::CompanyProfileRecord.create!(name: "Research Company", slug: company_tag.name,
    kind: "companies", listed: true, logo_upload: logo, facts: { company_tag_id: company_tag.id })
  fields = { svdex_presale_product_id: product.id, svdex_presale_summary: "Field instrument for lab research", svdex_presale_price: "$249 per device", svdex_presale_includes: "Device and kit", svdex_presale_delivery: "March 2027", svdex_presale_terms: "Shipping separately" }
  title = "Product approval #{SecureRandom.hex(5)}"
  args = { title: title, raw: "A product preorder with delivery information and questions for the maker.", category: category.id }
  [nil, product.category.topic_id, Topic.find_by!(category_id: SiteSetting.svdex_public_offerings_category_id).id].each do |invalid_id|
    rejected = NewPostManager.new(user, args.merge(svdex_presale_product_id: invalid_id)).perform
    raise "Campaign with an invalid product entered the review queue" unless rejected.failed? && !rejected.reviewable
  end
  result = NewPostManager.new(user, fields.merge(args)).perform
  raise "Product topic not queued: #{result.errors.full_messages}" unless result.success? && result.action == :enqueued
  raise "Product published before review" if Topic.exists?(title: title)
  reviewable = result.reviewable.reload
  payload = ReviewableQueuedPostSerializer.new(reviewable, scope: actor.guardian, root: false).as_json.fetch(:payload)
  fields.each { |key, value| raise "Review field lost: #{key}" unless payload[key.to_s] == value }
  approved = reviewable.perform(actor, :approve_post)
  raise "Approval failed" unless approved.success?
  post = approved.created_post
  topic = post.topic.reload
  guest = Guardian.new
  view = TopicViewSerializer.new(TopicView.new(topic.id, nil), scope: guest, root: false).as_json
  raise "Product details hidden from guest" unless view[:svdex_presale]["price"] == "$249 per device"
  raise "Product link lost" unless view[:svdex_presale].values_at("product_id", "product_title") == [product.id, product.title]
  campaign_logo = -> { TopicQuery.new(nil, category: category.id).list_latest.topics.find { |row| row.id == topic.id }.svdex_organization_logo }
  raise "Campaign did not inherit its linked product's public logo" unless campaign_logo.call == logo.url
  product.update!(visible: false)
  hidden_view = TopicViewSerializer.new(TopicView.new(topic.id, nil), scope: guest, root: false).as_json
  raise "Hidden product was exposed through a campaign" if hidden_view[:svdex_presale].key?("product_id")
  raise "Hidden product's logo was exposed through a campaign" if campaign_logo.call.present?
  product.update!(visible: true)
  raise "Product serialized as security" if view.key?(:svdex_listing)
  raise "Securities tags leaked into product" if topic.tags.where(name: %w[public-offering private-offering]).exists?
  reply = NewPostManager.new(user, topic_id: topic.id, raw: "Will this include a calibration kit and a carrying case?", skip_jobs: true).perform
  raise "Product reply was queued" unless reply.success? && reply.action == :create_post
  raise "Price edit failed" unless PostRevisor.new(post).revise!(actor, { svdex_presale_price: "$299 per device" })
  raise "Price edit lost" unless topic.reload.custom_fields["svdex_presale_price"] == "$299 per device"
  raise "Terms clear failed" unless PostRevisor.new(post).revise!(actor, { svdex_presale_terms: "" })
  raise "Terms not cleared" if topic.reload.custom_fields["svdex_presale_terms"].present?
  begin
    DiscourseSvdex::Presales.validate!("price", "x" * 81)
    raise "Unbounded price accepted"
  rescue Discourse::InvalidParameters
  end
  begin
    PostCreator.create!(actor, title: "Wrong product category #{SecureRandom.hex(4)}", raw: "Product fields must not be saved into securities offerings.", category: SiteSetting.svdex_public_offerings_category_id, svdex_presale_price: "$249", skip_validations: true, skip_jobs: true)
    raise "Product fields accepted on security"
  rescue Discourse::InvalidParameters
  end
  # Bid access checks depend on offering_category?, which must stay false here.
  raise "Product counted as offering" if DiscourseSvdex.listing?(topic)
  puts "PASS public products use native review and replies, preserve terms through approval/edit/clear, and remain separate from securities"
  raise ActiveRecord::Rollback
end
