# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
discussion = Category.find_by!(slug: "discussion")
listings = Category.find(SiteSetting.svdex_listings_category_id)
help = Category.find(SiteSetting.svdex_help_category_id)
staff = Category.find_by!(slug: "staff")
raise "Retired public categories remain" if Category.where(slug: %w[general feedback site-feedback]).where.not(id: help.id).exists?
raise "Unexpected public categories" unless Category.where(read_restricted: false).pluck(:id).sort == [discussion.id, listings.id, help.id, SiteSetting.svdex_introductions_category_id.to_i, SiteSetting.svdex_public_offerings_category_id.to_i, SiteSetting.svdex_events_category_id.to_i].sort
raise "Staff is public" unless staff.read_restricted? && !Guardian.new(nil).can_see?(staff)
raise "Listings review changed" unless listings.topic_posting_review_mode == "everyone"
raise "Composer defaults elsewhere" unless SiteSetting.default_composer_category.to_i == discussion.id

app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
app.get "/categories.json"
raise "Public categories unavailable" unless app.response.status == 200
ids = app.response.parsed_body.fetch("category_list").fetch("categories").map { |category| category.fetch("id") }
raise "Public category directory exposes the wrong categories" unless ids.sort == [discussion.id, listings.id, help.id, SiteSetting.svdex_introductions_category_id.to_i, SiteSetting.svdex_events_category_id.to_i].sort
puts "PASS guests see Offerings, Discussion and Feedback; Staff remains private; listing approval and composer default are preserved"

User.transaction do
  member = User.create!(username: "community_#{SecureRandom.hex(3)}", email: "#{SecureRandom.hex(8)}@example.invalid",
    password: SecureRandom.hex(24), active: true, approved: true, trust_level: 1)
  lounge = Chat::CategoryChannel.find_by!(name: "Lounge")
  raise "Lounge uses the wrong category" unless lounge.chatable_id == discussion.id
  raise "Member cannot use Lounge" unless member.guardian.can_join_chat_channel?(lounge)
  raise "Member can see Staff" if member.guardian.can_see?(staff)
  puts "PASS Lounge uses Discussion permissions; ordinary members can join it and cannot see Staff"
  raise ActiveRecord::Rollback
end
