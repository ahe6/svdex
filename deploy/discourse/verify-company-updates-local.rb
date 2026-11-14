# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
def assert_updates!(ok, message)
  raise message unless ok
  puts "PASS #{message}"
end
category = Category.find(SiteSetting.svdex_introductions_category_id)
assert_updates!(category.name == "Company & Fund Updates" && category.slug == "company-updates" && !Category.exists?(slug: "introductions"), "Updates replaces the standalone Introductions category")
actor = User.find_by!(username: "svdex")
company = User.find_by!(username: "svdex-company")
tag = Tag.find(company.custom_fields.fetch("svdex_company_tag_id"))
User.transaction do
  account = -> { User.create!(username: "updates_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(10)}@example.invalid", password: SecureRandom.hex(24), active: true, approved: true, trust_level: 2) }
  approved, outsider = account.call, account.call
  Group.find_by!(name: SiteSetting.svdex_companies_group_name).add(approved)
  assert_updates!(Guardian.new(approved.reload).can_create_topic_on_category?(category) && !outsider.guardian.can_create_topic_on_category?(category), "only approved organizations and staff may submit official updates")
  queued = NewPostManager.new(approved, title: "Organization milestone #{SecureRandom.hex(4)}", raw: "An official business milestone submitted for staff review before publication.", category: category.id, tags: [tag.name]).perform
  assert_updates!(queued.success? && queued.action == :enqueued, "nonstaff company updates require native moderation")
  update = PostCreator.create!(actor, title: "Company update #{SecureRandom.hex(4)}", raw: "A company update linked to the organization profile by its native tag.", category: category.id, tags: [tag.name], skip_validations: true, skip_jobs: true).topic
  independent = PostCreator.create!(actor, title: "Independent discussion #{SecureRandom.hex(4)}", raw: "An independent conversation about the company, separate from official updates.", category: Category.find_by!(slug: "discussion").id, tags: [tag.name], skip_validations: true, skip_jobs: true).topic
  TopTopic.create!(topic: update, all_score: 1_000_000)
  TopTopic.create!(topic: independent, all_score: 1_000_000)
  [nil, outsider, actor].each do |viewer|
    %i[latest top].each do |filter|
      query = TopicQuery.new(viewer, per_page: 100)
      ids = (filter == :top ? query.list_top_for(:all) : query.list_latest).topics.map(&:id)
      assert_updates!(ids.include?(update.id) && !ids.include?(independent.id), "Home mixes updates with offerings while excluding independent discussion")
    end
  end
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.get "/listings/company-profile/#{company.username}.json"
  payload = app.response.parsed_body
  assert_updates!(app.response.status == 200 && payload.fetch("updates").any? { |topic| topic["id"] == update.id } && payload.fetch("updates").none? { |topic| topic["id"] == independent.id } && payload.fetch("updates_url").include?(tag.slug), "guest company profiles link to the correct native update timeline")
  app.get "/private-offerings/summary.json"
  assert_updates!(app.response.status == 200 && app.response.parsed_body == {}, "public discovery reveals no restricted offering counts or activity")
  reply = NewPostManager.new(outsider, topic_id: update.id, raw: "Thanks for the update. Can you share more about the product milestone?", skip_jobs: true).perform
  assert_updates!(reply.success? && reply.action == :create_post, "ordinary members may reply to approved updates")
  raise ActiveRecord::Rollback
end
puts "Company update checks complete; all test records rolled back."
