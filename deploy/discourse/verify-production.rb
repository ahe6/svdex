# frozen_string_literal: true
# Run explicitly after deployment with guest browsing open. Every test record
# is isolated in a rollback; registration and real content remain unchanged.
abort "Explicit production check required" unless GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_PRODUCTION_CHECK"] == "1" && !SiteSetting.login_required
Middleware::AnonymousCache.disable_anon_cache
# Rolled-back fixtures still count toward native record-creation limits. This
# affects this short-lived verification process only, never the web workers.
RateLimiter.disable

def assert!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end

def session_for(user = nil, password = nil)
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "svdex.com"
  app.https!
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  if user
    app.post "/session.json", params: { login: user.username, password: password }, headers: headers
    assert!(app.response.status == 200 && app.response.parsed_body.dig("user", "id") == user.id, "native login succeeds")
  end
  [app, headers]
end

actor = User.find_by_email(ENV.fetch("DISCOURSE_DEVELOPER_EMAILS").split(",").first.strip)
assert!(actor&.admin? && actor.active?, "approved owner is an active administrator")
offerings = Category.find(SiteSetting.svdex_listings_category_id)
public_offerings = Category.find(SiteSetting.svdex_public_offerings_category_id)
assert!(offerings.slug == "offerings" && offerings.topic_posting_review_mode == "everyone" && offerings.reply_posting_review_mode == "no_one", "Offerings requires new-topic review and permits native replies")
assert!(Category.find_by!(slug: "staff").read_restricted?, "Staff category stays private")
public_categories = Category.secured(Guardian.new(nil)).where.not(id: SiteSetting.uncategorized_category_id).pluck(:slug).sort
assert!(public_categories == %w[company-updates discussion events feedback offerings public-offerings], "only reviewed community/update/event and public-offering categories are public")
assert!(SiteSetting.backup_with_uploads && SiteSetting.backup_frequency == 1, "daily native backups include uploads")
assert!(Badge.find_by!(name: "Verified Accredited Investor").grant_count == 0, "verification badge has no automatic or fixture awards")
assert!(DiscourseSvdex::CompanyDirectory::STAGES.include?("Non-venture") && !DiscourseSvdex::CompanyDirectory::STAGES.include?("Bootstrapped"), "stage vocabulary uses Non-venture")

Post.transaction do
  password = SecureRandom.hex(24)
  create_user = ->(admin = false) do
    user = User.create!(username: "launch_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: admin ? 1 : 0, admin: admin)
    user.email_tokens.update_all(confirmed: true)
    user
  end
  staff_user, member, company = create_user.call(true), create_user.call, create_user.call
  member.change_trust_level!(1)
  group = Group.find_by!(name: SiteSetting.svdex_companies_group_name)
  group.add(company)
  DirectoryItem.add_missing_users(:all)
  staff, headers = session_for(staff_user, password)
  ordinary, member_headers = session_for(member, password)
  guest, = session_for
  issuer_tag = Tag.create!(name: "launch-#{SecureRandom.hex(6)}")
  TagGroup.find_by_name_insensitive("Companies").tags << issuer_tag
  field_path = "/listings/company-details/#{company.id}.json"
  staff.put field_path, params: { company: { total_funding_usd: "900000", last_valuation_usd: "20000000", stage: "Non-venture", headquarters_country: "United States", sector_tag_id: Tag.find_by!(name: "software").id.to_s, company_tag_id: issuer_tag.id.to_s } }, headers: headers
  assert!(staff.response.status == 200, "staff can edit numeric company facts")
  ordinary.put field_path, params: { company: { total_funding_usd: "1" } }, headers: member_headers
  assert!(ordinary.response.status == 403, "ordinary members cannot edit company financials")
  guest.get "/listings/company-profile/#{company.username}.json"
  puts "Guest profile status=#{guest.response.status}; keys=#{guest.response.parsed_body.keys.inspect}; global_profile_access=#{Guardian.new(nil).public_can_see_profiles?}; login_required=#{SiteSetting.login_required}"
  assert!(guest.response.status == 200 && guest.response.parsed_body.dig("company", "total_funding_usd") == 900000, "guest can read public company Summary")
  guest.get "/listings/company-directory.json", params: { svdex_stage: "Non-venture", svdex_funding: "under_1m" }
  assert!(guest.response.status == 200 && guest.response.parsed_body.fetch("directory_items").any? { |r| r.dig("user", "id") == company.id }, "guest company filters use current facts")
  guardian = Guardian.new(nil)
  assert!(guardian.can_see_profile?(member) == guardian.method(:can_see_profile?).super_method.call(member), "ordinary-account native privacy is unchanged")

  title = "Launch verification #{SecureRandom.hex(8)}"
  result = NewPostManager.new(member, title: title, raw: "Offering review workflow verification with structured financial fields preserved.", category: public_offerings.id, tags: ["software", issuer_tag.name], svdex_summary: "Structured company research", svdex_post_money_valuation_usd: "20000000", skip_jobs: true).perform
  assert!(result.success? && result.action == :enqueued && !Topic.exists?(title: title), "member offering stays hidden pending review")
  approved = result.reviewable.perform(actor, :approve_post)
  assert!(approved.success? && approved.created_post.topic.reload.custom_fields["svdex_post_money_valuation_usd"] == 20000000, "approval preserves structured offering fields")
  topic = approved.created_post.topic
  ordinary.post "/bookmarks.json", params: { bookmarkable_id: topic.id, bookmarkable_type: "Topic" }, headers: member_headers
  assert!(ordinary.response.status == 200 && Bookmark.exists?(user: member, bookmarkable: topic), "native bookmarking works")
  reply = NewPostManager.new(member, topic_id: topic.id, raw: "When is the next update expected for this offering and the company?", skip_jobs: true).perform
  assert!(reply.success? && reply.action == :create_post, "offering replies keep native posting behavior")
  if SiteSetting.svdex_interest_enabled
    interest_path = "/listings/interests/#{company.id}/buy.json"
    ordinary.put interest_path, params: { interest: { amount: "1.25", currency: "USD", market: "either", confirmation: "nonbinding-public-v1" } }, headers: member_headers
    assert!(ordinary.response.status == 200, "member can record a private owned indication with explicit aggregate consent")
    guest.get "/listings/interests/#{company.id}.json"
    assert!([403, 404].include?(guest.response.status), "guests cannot read individual indications")
    ordinary.get "/listings/my-interest.json"
    assert!(ordinary.response.status == 200 && ordinary.response.parsed_body.fetch("records").any? { |r| r["kind"] == "interest" && r["amount_cents"] == 125 }, "owner history contains exact submitted amount")
    staff.get "/listings/my-interest.json", params: { user_id: member.id }
    assert!(staff.response.status == 200 && staff.response.parsed_body.fetch("records").empty?, "staff history cannot impersonate another submitter")
    ordinary.delete interest_path, headers: member_headers
    assert!(ordinary.response.status == 200, "member can withdraw their own indication")
  end
  if SiteSetting.svdex_bids_enabled
    bid_path = "/listings/offering-bids/#{topic.id}.json"
    ordinary.put bid_path, params: { bid: { amount: "1.50", currency: "USD", proposed_terms: "Nonbinding verification of private submission handling", confirmation: "nonbinding-bid-v1" } }, headers: member_headers
    assert!(ordinary.response.status == 200 && ordinary.response.parsed_body.dig("bid", "amount_cents") == 150, "member can submit an offering-specific private bid")
    guest.get bid_path
    assert!([403, 404].include?(guest.response.status), "guests cannot read individual bids")
    private_topic = PostCreator.create!(actor, title: "Restricted release check #{SecureRandom.hex(6)}", raw: "Restricted category access verification.", category: SiteSetting.svdex_private_offerings_category_id, tags: [issuer_tag.name, "software"], skip_validations: true, skip_jobs: true).topic
    ordinary.get "/listings/offering-bids/#{private_topic.id}.json"
    assert!(ordinary.response.status == 404, "ordinary members cannot inspect bids in inaccessible offerings")
    ordinary.delete bid_path, headers: member_headers
    assert!(ordinary.response.status == 200, "member can withdraw their own bid")
  end
  discussion = Category.find_by!(slug: "discussion")
  ordinary_topic = NewPostManager.new(member, title: "Company research #{SecureRandom.hex(8)}", raw: "Research sources and market insights shared with the community for discussion.", category: discussion.id, tags: ["software"], skip_jobs: true).perform
  assert!(ordinary_topic.success? && ordinary_topic.action == :create_post, "ordinary Discussion topics publish normally")
  assert!(!member.guardian.can_create_category? && !member.guardian.can_create_group?, "members cannot create administrative groups or categories")
  channel = Chat::CategoryChannel.find_by!(chatable: discussion, name: "Lounge")
  assert!(member.guardian.can_preview_chat_channel?(channel), "member can access the public Lounge channel")
  ordinary.delete "/session/#{member.username}.json", headers: member_headers
  assert!(ordinary.response.status == 200, "native logout works")
  raise ActiveRecord::Rollback
end
assert!(!User.where("username LIKE 'launch_%'").exists?, "all launch test accounts rolled back")
puts "Production smoke checks complete; temporary records rolled back and registration unchanged."
