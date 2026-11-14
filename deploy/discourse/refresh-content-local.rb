# frozen_string_literal: true
# Idempotent local editorial fixtures. Never run or import these on production.
abort "Local content only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
actor = User.find_by!(username: "svdex")
updates = Category.find(SiteSetting.svdex_introductions_category_id)
discussion = Category.find_by!(slug: "discussion")
feedback = Category.find(SiteSetting.svdex_help_category_id)
rows = [
  ["svdex-research-release", "svdex-company", updates, %w[svdex finance], "SVDEX: company research and offering discovery, together", "We have brought company profiles, funding history and current offerings into one research workflow.\n\nStart with a company profile, compare the disclosed terms of its offerings, and follow its official updates. Company-level buy and sell interest is nonbinding and separate from any particular financing.\n\nWhat information would make your first pass on a company easier?"],
  ["northstar-lab-update", "northstar", updates, %w[northstar hardware], "Northstar Instruments: optical platform reaches lab validation", "Our compact optical platform has completed its next laboratory validation milestone.\n\nThe engineering team is now working on repeatability and integration with existing research equipment. Our company profile provides the business context; financing terms belong in the separate offering topic.\n\nWe welcome questions from researchers about installation, calibration and long-term support."],
  ["svdex-fund-letter", "svdex-fund-i", updates, %w[svdex-fund-i finance], "SVDEX Opportunity Fund I: investment approach and fund timeline", "Our focus is software and infrastructure for private capital markets.\n\nThe fund profile brings together strategy, manager information, fund life and disclosed fund size. We will use this update thread for portfolio-level developments and future investor communications.\n\nQuestions about the strategy are welcome here. Specific subscription or transfer opportunities will have their own offering topics."],
  ["research-checklist", "svdex", discussion, %w[finance], "What do you check before reading an offering's terms?", "I usually begin with the business, its funding history and the people involved, then compare the instrument and price.\n\nWhat belongs in a useful first-pass research checklist? How do you separate company-level information from terms that only apply to one financing?"],
  ["secondary-transfer-questions", "svdex", discussion, %w[finance], "Secondary share transfers: which questions should buyers ask?", "Transfer approvals, existing shareholder rights and the identity of the seller can matter as much as the headline price.\n\nWhat questions help uncover restrictions before someone spends time negotiating a secondary purchase? Please keep the discussion general and avoid posting private deal documents."],
  ["directory-feedback", "svdex", feedback, %w[community], "Which company profile fields are most useful for your research?", "We are refining company and fund profiles alongside the offering feed.\n\nTell us which facts help you decide what to read next, which labels are unclear, and where the mobile experience slows you down. For bugs, include the page and what you expected to happen."],
]
rows.each_with_index do |(key, username, category, tags, title, raw), index|
  user = User.find_by!(username: username)
  topic = TopicCustomField.find_by(name: "svdex_editorial_source", value: key)&.topic
  if topic
    PostRevisor.new(topic.first_post).revise!(actor, { title: title, raw: raw, category_id: category.id, tags: tags }, skip_validations: true)
  else
    topic = PostCreator.create!(user, title: title, raw: raw, category: category.id, tags: tags, skip_validations: true, skip_jobs: false).topic
    topic.custom_fields["svdex_editorial_source"] = key
    topic.save_custom_fields
  end
  # Stable, realistic ordering without manufacturing replies, views or interest.
  topic.update_columns(bumped_at: (index + 1).hours.ago)
  TopTopic.find_or_create_by!(topic: topic).update!(all_score: 50 - index)
  puts "Updated #{topic.relative_url}"
end
# Give the existing financing fixtures instrument-specific summaries rather
# than repeating each company's permanent profile description. Terms stay intact.
{
  "svdex-series-a-preferred" => "Preferred equity for expanding company research and private-market data coverage.",
  "svdex-ordinary-shares" => "Secondary ordinary shares; price and transfer conditions are not yet disclosed.",
}.each do |key, summary|
  topic = TopicCustomField.find_by(name: "svdex_source_id", value: key)&.topic
  next unless topic
  topic.custom_fields["svdex_summary"] = summary
  topic.save_custom_fields
end
{
  "SVDEX — Pre-seed SAFE" => "A capped SAFE supporting the next phase of the SVDEX research platform.",
  "SVDEX — Convertible Note" => "Convertible debt with a valuation cap, conversion discount and annual interest.",
  "Northstar Instruments — 2030 Bond" => "Fixed-rate debt supporting optical instrument manufacturing and lab deployments.",
}.each do |title, summary|
  topic = Topic.find_by(title: title)
  next unless topic && DiscourseSvdex.offering_category_ids.include?(topic.category_id)
  topic.custom_fields["svdex_summary"] = summary
  topic.save_custom_fields
end
# Move existing native calendar topics to the dedicated Events category. Native
# PostRevisor preserves IDs, event data, RSVPs and links.
TopicCustomField.where(name: "svdex_event_source").includes(topic: :first_post).each do |field|
  topic = field.topic
  next unless topic && topic.category_id != SiteSetting.svdex_events_category_id
  PostRevisor.new(topic.first_post).revise!(actor, { category_id: SiteSetting.svdex_events_category_id }, skip_validations: true)
end
puts "Local editorial refresh complete; no records or financial indications removed or fabricated."
