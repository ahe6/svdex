# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
Middleware::AnonymousCache.disable_anon_cache
def feed_assert!(value, message)
  raise message unless value
  puts "PASS #{message}"
end
Topic.transaction do
  actor = User.find_by!(username: "svdex")
  discussion = Category.find_by!(slug: "discussion")
  products = Category.find(SiteSetting.svdex_products_category_id)
  presales = Category.find(SiteSetting.svdex_presales_category_id)
  events = Category.find(SiteSetting.svdex_events_category_id)
  create = ->(category, title) { PostCreator.create!(actor, title: "#{title} #{SecureRandom.hex(5)}", raw: "Details for this community research topic.", category: category.id, skip_validations: true, skip_jobs: true).topic }
  old, fresh = create.call(discussion, "Older research"), create.call(discussion, "New research")
  old.update_columns(created_at: 3.days.ago, bumped_at: Time.current)
  fresh.update_columns(created_at: 1.day.ago, bumped_at: 1.day.ago)
  select = ->(list, ids) { list.topics.map(&:id) & ids }
  ids = [old.id, fresh.id]
  feed_assert!(select.call(TopicQuery.new(nil, category: discussion.id, svdex_view: "latest").list_latest, ids) == [fresh.id, old.id], "Latest uses creation date even when an older topic gets activity")
  feed_assert!(select.call(TopicQuery.new(nil, category: discussion.id, svdex_view: "activity").list_latest, ids) == ids, "Activity uses native bumped-at order")
  feed_assert!(select.call(TopicQuery.new(nil, category: discussion.id).list_latest, ids) == ids, "Discussion defaults to Activity")
  updates = Category.find(SiteSetting.svdex_introductions_category_id)
  older_update, fresh_update = create.call(updates, "Older company update"), create.call(updates, "Fresh company update")
  older_update.update_columns(created_at: 3.days.ago, bumped_at: Time.current)
  fresh_update.update_columns(created_at: 1.day.ago, bumped_at: 1.day.ago)
  feed_assert!(select.call(TopicQuery.new(nil).list_latest, [older_update.id, fresh_update.id]) == [older_update.id, fresh_update.id], "Home Latest defaults to native recent activity")
  product, campaign = create.call(products, "Research workspace"), create.call(presales, "Research hardware campaign")
  feed_assert!(select.call(TopicQuery.new(nil, category: products.id).list_latest, [product.id, campaign.id]).sort == [product.id, campaign.id].sort, "Products stays mixed by default")
  feed_assert!(select.call(TopicQuery.new(nil, category: products.id, svdex_presales: "1").list_latest, [product.id, campaign.id]) == [campaign.id], "Pre-sales availability filters by category before pagination")
  feed_assert!(select.call(TopicQuery.new(nil, category: products.id, svdex_presales: "0").list_latest, [product.id, campaign.id]) == [product.id], "Launched availability excludes pre-sales before pagination")
  guest = ActionDispatch::Integration::Session.new(Rails.application)
  guest.host! "localhost"
  guest.get "#{products.url}/l/top.json?period=all&svdex_presales=1"
  feed_assert!(guest.response.status == 200 && guest.response.parsed_body.dig("topic_list", "topics").none? { |t| t["id"] == product.id }, "native Top accepts the same pre-sales filter")
  dated = lambda do |label, start, finish, category = events|
    topic = create.call(category, label)
    event = DiscourseEvents::Events::Event.create!(id: topic.first_post.id, original_starts_at: start, original_ends_at: finish)
    event.event_dates.create!(starts_at: start, ends_at: finish)
    topic
  end
  ongoing = dated.call("Research office hours", 1.hour.ago, 1.hour.from_now)
  soon = dated.call("Near event", 2.hours.from_now, 3.hours.from_now)
  later = dated.call("Later event", 2.days.from_now, 2.days.from_now + 1.hour)
  recent = dated.call("Recent event", 1.day.ago, 1.day.ago + 1.hour)
  older = dated.call("Older event", 3.days.ago, 3.days.ago + 1.hour)
  private_event = dated.call("Restricted event", 1.hour.from_now, 2.hours.from_now, Category.find(SiteSetting.svdex_private_offerings_category_id))
  all = [ongoing, soon, later, recent, older, private_event].map(&:id)
  upcoming = TopicQuery.new(nil, category: events.id).list_latest
  feed_assert!(select.call(upcoming, all) == [ongoing.id, soon.id, later.id], "Upcoming includes ongoing events and orders by native start date")
  past = TopicQuery.new(nil, category: events.id, svdex_view: "past").list_latest
  feed_assert!(select.call(past, all) == [recent.id, older.id], "Past excludes ongoing/future events and orders newest event first")
  guest.get "#{events.url}/l/latest.json?svdex_view=past"
  feed_assert!(guest.response.status == 200 && (guest.response.parsed_body.dig("topic_list", "topics").map { |t| t["id"] } & all) == [recent.id, older.id], "event view URLs preserve native anonymous permissions")
  raise ActiveRecord::Rollback
end
puts "Feed view checks complete; scenario records rolled back."
