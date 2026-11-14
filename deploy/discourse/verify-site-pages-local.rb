# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
source = "/tmp/apply-site-pages.rb"
ActiveRecord::Base.transaction do
  native_settings = %i[privacy_topic_id tos_topic_id]
  guidelines_before = Topic.find(SiteSetting.guidelines_topic_id).first_post.raw
  old_ids = native_settings.to_h { |key| [key, SiteSetting.public_send(key)] }
  bumps = Topic.where(id: old_ids.values).pluck(:id, :bumped_at).to_h
  load source
  ids = native_settings.map { |key| SiteSetting.public_send(key) }
  count = Topic.with_deleted.count
  load source
  raise "Repeated application changed policy IDs" unless native_settings.map { |key| SiteSetting.public_send(key) } == ids
  raise "Repeated application created topics" unless Topic.with_deleted.count == count
  bumps.each { |id, stamp| raise "Existing policy bumped" unless Topic.find(id).bumped_at == stamp }
  puts "PASS native pages update in place without duplicate topics or activity bumps"

  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  { "/privacy" => "Private-access applications", "/tos" => "Research, discussion and offerings" }.each do |path, text|
    app.get path
    raise "Guest page failed: #{path} #{app.response.status}" unless app.response.status == 200
    raise "Missing page body: #{path}" unless app.response.body.include?(text)
    raise "Unresolved operator field" if app.response.body.match?(/\{\{(?:operator|effective)/)
    raise "Missing native Privacy or Terms navigation" unless app.response.body.include?("nav-item-privacy") && app.response.body.include?("nav-item-tos")
  end
  raise "Native help links still target a retired page" unless SiteSetting.faq_url == "#{Discourse.base_url}/tos"
  puts "PASS guests see complete native Privacy and Terms with legal navigation"
  raise "Guidelines was unexpectedly rewritten" unless Topic.find(SiteSetting.guidelines_topic_id).first_post.raw == guidelines_before
  raise "Terms still depend on Guidelines" if Topic.find(SiteSetting.tos_topic_id).first_post.raw.include?("/guidelines")
  ids.each do |id|
    raise "Policy source topic should not enter feeds" if Topic.find(id).visible?
    raise "Policy editing topic should remain staff-only" if Guardian.new.can_see_topic?(Topic.find(id))
  end
  %w[/about /about.json /guidelines /faq /rules /conduct].each do |path|
    app.get path
    raise "Retired page remains accessible: #{path}" unless app.response.status == 404
  end
  app.get "/about/live_post_counts.json"
  raise "Unrelated native About controller action changed" unless app.response.status == 403
  puts "PASS About and Guidelines aliases no longer serve pages; legal pages and staff-only editing remain intact"
  raise ActiveRecord::Rollback
end
