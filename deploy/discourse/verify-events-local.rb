# frozen_string_literal: true
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache

def assert!(condition, label)
  raise label unless condition
  puts "PASS #{label}"
end

assert!(SiteSetting.discourse_events_enabled && SiteSetting.discourse_post_event_enabled, "native Events is enabled")
assert!(SiteSetting.discourse_post_event_allowed_on_groups_map.sort == [1, 2, 10], "signed-in members can create native events")
events = Category.find(SiteSetting.svdex_events_category_id)
assert!(!events.read_restricted? && SiteSetting.calendar_upcoming_events_default_category.to_i == events.id, "calendar defaults to the public Events category")
actor = User.find_by!(username: "svdex")
assert!(actor.guardian.can_create_discourse_post_event?, "staff can create native events")

Post.transaction do
  password = SecureRandom.hex(24)
  member = User.create!(username: "event_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: 1)
  member.email_tokens.update_all(confirmed: true)
  assert!(member.guardian.can_create_discourse_post_event?, "ordinary members can create events")
  assert!(!Guardian.new.can_create_discourse_post_event?, "guests cannot create events")
  start = 3.days.from_now.in_time_zone("Asia/Shanghai").change(hour: 17, min: 0, sec: 0)
  raw = "Community questions and research discussion.\n\n[event start=\"#{start.strftime('%Y-%m-%d %H:%M')}\" timezone=\"Asia/Shanghai\" status=\"public\"]\n[/event]"
  public_post = PostCreator.create!(actor, title: "Community event #{SecureRandom.hex(6)}", raw: raw, category: events.id, tags: ["community"], skip_jobs: true)
  private_post = PostCreator.create!(actor, title: "Private event #{SecureRandom.hex(6)}", raw: raw, category: SiteSetting.svdex_private_offerings_category_id, tags: %w[svdex finance], skip_jobs: true)
  assert!(public_post.reload.event && private_post.reload.event, "native event blocks persist through ordinary topic creation")
  # The native after_commit callback creates occurrences in normal operation.
  # This verification rolls back, so materialize those same native date records.
  [public_post, private_post].each { |post| post.event.event_dates.create!(starts_at: start.utc, ends_at: start.utc + 1.hour) }
  assert!(public_post.event.original_starts_at == start.utc, "native event timezone is preserved")
  guest = ActionDispatch::Integration::Session.new(Rails.application)
  guest.host! "localhost"
  guest.get "/upcoming-events"
  assert!(guest.response.status == 200, "guest upcoming-events page loads")
  guest.get "/discourse-post-event/events.json"
  ids = guest.response.parsed_body.fetch("events").map { |event| event.fetch("id") }
  assert!(ids.include?(public_post.id) && !ids.include?(private_post.id), "public calendar lists public events and hides restricted topics")
  guest.get "/discourse-post-event/events.ics"
  assert!(guest.response.status == 200 && guest.response.body.include?(public_post.topic.title) && !guest.response.body.include?(private_post.topic.title), "calendar export preserves private-category access controls")
  guest.get "/discourse-post-event/events/#{private_post.id}.json"
  assert!([403, 404].include?(guest.response.status), "direct private event details remain protected")

  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "localhost"
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: member.username, password: password }, headers: headers
  assert!(app.response.status == 200, "ordinary event participant can log in")
  app.post "/discourse-post-event/events/#{public_post.id}/invitees", params: { invitee: { status: "going" } }, headers: headers
  assert!(app.response.status == 200 && DiscourseEvents::Events::Invitee.exists?(post_id: public_post.id, user_id: member.id, status: DiscourseEvents::Events::Invitee.statuses[:going]), "ordinary members can RSVP to public events")
  member.user_option.update!(event_reminder_preference: "personal_message")
  before_messages = Topic.private_messages_for_user(member).count
  Jobs::DiscoursePostEventSendReminder.new.execute(event_id: public_post.id, reminder: "1.days")
  assert!(Topic.private_messages_for_user(member).count == before_messages + 1, "native reminders create a personal message for opted-in attendees")
  member.user_option.update!(event_reminder_preference: "none")
  Jobs::DiscoursePostEventSendReminder.new.execute(event_id: public_post.id, reminder: "1.days")
  assert!(Topic.private_messages_for_user(member).count == before_messages + 1, "native reminder opt-out is respected")
  app.delete "/discourse-post-event/events/#{public_post.id}", headers: headers
  assert!(app.response.status == 403 && public_post.reload.event.present?, "ordinary participants cannot delete staff events")
  app.post "/posts.json", params: { title: "Member event #{SecureRandom.hex(5)}", raw: raw, category: events.id, tags: ["community"] }, headers: headers
  assert!(app.response.status == 200 && Post.find(app.response.parsed_body.fetch("id")).event.present?, "ordinary members can publish event topics in Events")
  assert!(DiscourseEvents::Events::Finder.search(actor, {}).map(&:id).include?(private_post.id), "authorized staff can see restricted events in the native calendar")
  raise ActiveRecord::Rollback
end
