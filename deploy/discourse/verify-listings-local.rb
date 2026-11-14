# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
def assert!(condition, label)
  raise label unless condition
  puts "PASS #{label}"
end
parent = Category.find(SiteSetting.svdex_listings_category_id)
category = Category.find(SiteSetting.svdex_public_offerings_category_id)
app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
app.get "/listings"
assert! app.response.status == 302 && app.response.location.end_with?(parent.url), "old listings URL redirects to native category"
app.get "/listings/does-not-exist"
assert! app.response.status == 404, "unknown old detail URLs fail safely"
app.get "/listings/watchlist"
assert! [302, 403, 404].include?(app.response.status), "saved topics require a native login"
app.post "/posts.json", params: { title: "Unauthorized listing", raw: "An anonymous user must not be able to publish a listing.", category: category.id }
assert! [403, 422].include?(app.response.status), "guests cannot create listings"

# Real model/service operations, rolled back so verification leaves no test content.
Post.transaction do
  owner = User.create!(username: "listing_check_#{SecureRandom.hex(3)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 1)
  other = User.create!(username: "listing_other_#{SecureRandom.hex(3)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 1)
  post = PostCreator.create!(owner, title: "Optical laboratory instruments", raw: "Compact optical instruments for laboratory research and independent testing.", category: category.id, skip_validations: true, skip_jobs: true,
    svdex_summary: "Compact optical instruments for research laboratories", svdex_terms: "USD 8m pre-money", svdex_offering_size: "USD 2m", svdex_minimum: "USD 100")
  topic = post.topic.reload
  source_id = "compat-#{SecureRandom.hex(6)}"
  topic.custom_fields["svdex_source_id"] = source_id
  topic.save_custom_fields
  app.get "#{category.url}.json"
  body = JSON.parse(app.response.body)
  listing = body.fetch("topic_list").fetch("topics").find { |item| item["id"] == topic.id }
  assert! listing && listing["svdex_listing"].key?("minimum"), "native category serializes structured listing fields"
  assert! body["topic_list"]["topics"].none? { |item| item["id"] == category.topic_id }, "category description is not a listing"
  app.get "/listings/#{source_id}"
  assert! app.response.status == 302 && app.response.location.include?("/t/"), "old detail link opens a topic"
  assert! topic.custom_fields["svdex_terms"] == "USD 8m pre-money", "creating a topic persists financial fields"
  assert! !other.guardian.can_edit?(post) && !Guardian.new(nil).can_edit?(post), "listing editing uses native ownership permissions"
  assert! PostRevisor.new(post).revise!(owner, { raw: post.raw, svdex_summary: "Updated laboratory instruments", svdex_terms: "USD 9m pre-money" }, skip_validations: true), "field-only edit succeeds through native post revision"
  assert! topic.reload.custom_fields["svdex_summary"] == "Updated laboratory instruments" && topic.custom_fields["svdex_terms"] == "USD 9m pre-money", "edited fields persist"
  assert! PostRevisor.new(post).revise!(owner, { raw: "Updated overview of compact laboratory instruments and their planned testing." }, skip_validations: true), "ordinary first-post edits still work"
  assert! topic.reload.custom_fields["svdex_terms"] == "USD 9m pre-money", "body-only edits preserve financial fields"
  rejected = false
  begin
    PostRevisor.new(post).revise!(owner, { raw: post.raw, svdex_summary: "x" * 181 }, skip_validations: true)
  rescue Discourse::InvalidParameters
    rejected = true
  end
  assert! rejected, "server rejects oversized fields"
  reply = PostCreator.create!(owner, topic_id: topic.id, raw: "What is the timeline for independent laboratory testing?", skip_validations: true, skip_jobs: true)
  rejected = false
  begin
    PostRevisor.new(reply).revise!(owner, { raw: reply.raw, svdex_terms: "tampered" }, skip_validations: true)
  rescue Discourse::InvalidParameters
    rejected = true
  end
  assert! rejected && topic.reload.custom_fields["svdex_terms"] == "USD 9m pre-money", "replies cannot change listing fields"
  manager = BookmarkManager.new(owner)
  bookmark = manager.create_for(bookmarkable_id: topic.id, bookmarkable_type: "Topic")
  assert! bookmark.is_a?(Bookmark) && bookmark.persisted?, "listing saves use native bookmarks"
  # A restricted listing must stay invisible, including through compatibility links.
  group = Group.create!(name: "listing_check_#{SecureRandom.hex(3)}")
  restricted = Category.create!(name: "Listing check #{SecureRandom.hex(3)}", user: Discourse.system_user)
  restricted.set_permissions(group.name => :full)
  restricted.save!
  post.topic.update!(category_id: restricted.id)
  assert! !Guardian.new(nil).can_see?(post.topic.reload), "native category access controls protect restricted topics"
  raise ActiveRecord::Rollback
end
