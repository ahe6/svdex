# frozen_string_literal: true
# Local visual-review fixtures only. Never package or import these records into production.
abort "Local setup only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
actor = User.find_by!(username: "svdex")
company = User.find_by!(username: "svdex-company")
fund = User.find_by!(username: "svdex-fund-i")
now = Time.current
ActiveRecord::Base.transaction do
  [[company, "buy", 2_500_000, 90.days.from_now, nil],
   [company, "sell", 1_000_000, 2.days.ago, nil],
   [fund, "buy", 5_000_000, 90.days.from_now, 1.day.ago]].each do |organization, side, amount, expiry, withdrawal|
    next if DiscourseSvdex::InterestIndication.exists?(user: actor, organization: organization, side: side)
    DiscourseSvdex::InterestIndication.create!(user: actor, organization: organization, side: side,
      market: side == "sell" ? "secondary" : "either", amount_cents: amount, currency: "USD",
      expires_at: expiry, withdrawn_at: withdrawal, aggregate_consent_at: now)
  end
  offerings = DiscourseSvdex::CompanyDirectory.offering_scope(actor.guardian).joins(:tags)
    .where(tags: {id: company.custom_fields["svdex_company_tag_id"].to_i}).order(:id).limit(2)
  offerings.each_with_index do |topic, index|
    next if DiscourseSvdex::OfferingBid.exists?(user: actor, topic: topic)
    DiscourseSvdex::OfferingBid.create!(user: actor, organization: company, topic: topic,
      amount_cents: index.zero? ? 5_000_000 : 1_500_000, currency: "USD",
      proposed_terms: index.zero? ? "At the posted terms, subject to final documents and allocation." : "Subject to review of the financing documents and transfer restrictions.",
      confirmed_at: now, expires_at: index.zero? ? 90.days.from_now : 1.day.ago)
  end
end
SiteSetting.svdex_bids_enabled = true
SiteSetting.svdex_bids_staff_preview = true
puts "Local financial activity ready at /u/#{actor.username}/activity/interest; existing submissions preserved."
