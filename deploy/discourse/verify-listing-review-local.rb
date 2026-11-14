# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_public_offerings_category_id)
raise "Topic review disabled" unless category.topic_posting_review_mode == "everyone"
raise "Replies unexpectedly moderated" unless category.reply_posting_review_mode == "no_one"
actor = User.find_by!(username: "svdex")

Post.transaction do
  create_user = -> { User.create!(username: "review_check_#{SecureRandom.hex(3)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2) }
  user = create_user.call
  company_tag = Tag.create!(name: "company-check-#{SecureRandom.hex(3)}")
  tags = [company_tag.name, "hardware"]
  title = "Listing approval #{SecureRandom.hex(6)}"
  fields = {
    svdex_summary: "Optical instruments for laboratory research",
    svdex_terms: "Repayment on maturity", svdex_interest_rate: "8% annually",
    svdex_offering_size: "USD 2,000,000", svdex_funds_raised: "USD 250,000",
    svdex_total_funding: "USD 12,500,000",
    svdex_valuation_cap: "USD 10,000,000", svdex_conversion_discount: "20%",
    svdex_strike_price: "USD 2.50", svdex_expiration: "2030-06-30",
    svdex_minimum: "USD 100", svdex_post_money_valuation_usd: "50000000",
  }
  result = NewPostManager.new(user, fields.merge(title: title, raw: "Offering terms and company research for the approval workflow verification.", category: category.id, tags: tags)).perform
  raise "Topic was not queued: #{result.errors.full_messages}" unless result.success? && result.action == :enqueued
  raise "Unapproved topic was published" if Topic.exists?(title: title)
  reviewable = result.reviewable.reload
  fields.each { |key, value| raise "Queued field lost: #{key}" unless reviewable.payload[key.to_s] == value }
  serialized = ReviewableQueuedPostSerializer.new(reviewable, scope: actor.guardian, root: false).as_json
  fields.each { |key, value| raise "Reviewer cannot see field: #{key}" unless serialized.fetch(:payload)[key.to_s] == value }
  raise "Wrong review category" unless reviewable.category_id == category.id
  approved = reviewable.perform(actor, :approve_post)
  raise "Approval failed" unless approved.success?
  post = approved.created_post
  topic = post.topic.reload
  raise "Approved listing was not published" unless topic.visible? && reviewable.reload.approved?
  fields.each do |key, value|
    expected = key == :svdex_post_money_valuation_usd ? value.to_i : value
    raise "Approved field lost: #{key}" unless topic.custom_fields[key.to_s] == expected
  end
  raise "Company tags lost" unless (topic.tags.pluck(:name) & tags).size == tags.size
  raise "Approved offering visibility tag missing" unless topic.tags.exists?(name: "public-offering")
  reply = NewPostManager.new(create_user.call, topic_id: topic.id, raw: "When does the offering close and when are the next company updates?", skip_jobs: true).perform
  raise "Reply unexpectedly queued" unless reply.success? && reply.action == :create_post
  general = Category.find_by!(slug: "discussion")
  ordinary = NewPostManager.new(create_user.call, title: "General discussion #{SecureRandom.hex(6)}", raw: "An ordinary discussion topic should still publish without category approval.", category: general.id, skip_jobs: true).perform
  raise "General topics unexpectedly queued" unless ordinary.success? && ordinary.action == :create_post
  staff_manager = NewPostManager.new(actor, title: "Staff listing #{SecureRandom.hex(6)}", raw: "Staff retain the native review exemption when submitting a listing.", category: category.id)
  raise "Native staff exemption changed" unless NewPostManager.post_needs_approval?(staff_manager) == :skip
  puts "PASS new listings queued, hidden before approval, fields/tags preserved after approval; replies and ordinary discussions publish normally; staff retain native exemption"
  raise ActiveRecord::Rollback
end
