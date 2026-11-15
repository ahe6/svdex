# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
category = Category.find(SiteSetting.svdex_public_offerings_category_id)
actor = Discourse.system_user
Post.transaction do
  post = PostCreator.create!(actor, title: "Financial fields #{SecureRandom.hex(5)}", raw: "Transaction-scoped field verification.", category: category.id,
    svdex_instrument_type: "debt", svdex_funds_raised: "USD 250,000", svdex_offering_size: "USD 2,000,000",
    svdex_interest_rate: "8% annually", svdex_terms: "36-month maturity", svdex_post_money_valuation_usd: "50000000", skip_validations: true, skip_jobs: true)
  topic = post.topic.reload
  raise "instrument create" unless topic.custom_fields["svdex_instrument_type"] == "debt"
  raise "instrument edit" unless PostRevisor.new(post).revise!(actor, { svdex_instrument_type: "warrant" })
  raise "instrument not saved" unless topic.reload.custom_fields["svdex_instrument_type"] == "warrant"
  %w[not-an-instrument Equity].each do |value|
    begin
      DiscourseSvdex.validate_field!("svdex_instrument_type", value)
      raise "invalid instrument accepted"
    rescue Discourse::InvalidParameters
    end
  end
  raise "create" unless topic.custom_fields["svdex_interest_rate"] == "8% annually"
  revisor = PostRevisor.new(post)
  raise "edit" unless revisor.revise!(actor, { svdex_interest_rate: "9% annually" })
  topic.reload
  raise "rate edit" unless topic.custom_fields["svdex_interest_rate"] == "9% annually"
  raise "terms changed" unless topic.custom_fields["svdex_terms"] == "36-month maturity"
  raise "valuation changed" unless topic.custom_fields[DiscourseSvdex::VALUATION_FIELD] == 50_000_000
  raise "raised create" unless topic.custom_fields["svdex_funds_raised"] == "USD 250,000"
  raise "raised edit" unless PostRevisor.new(post).revise!(actor, { svdex_funds_raised: "USD 500,000" })
  topic.reload
  raise "raised not updated" unless topic.custom_fields["svdex_funds_raised"] == "USD 500,000"
  raise "offering target changed" unless topic.custom_fields["svdex_offering_size"] == "USD 2,000,000"
  raise "rate changed" unless topic.custom_fields["svdex_interest_rate"] == "9% annually"
  serializer = TopicViewSerializer.new(TopicView.new(topic.id, actor), scope: actor.guardian, root: false)
  values = serializer.as_json.fetch(:svdex_listing)
  raise "instrument serialization" unless values["instrument_type"] == "warrant"
  raise "serialization" unless values["interest_rate"] == "9% annually" && values["post_money_valuation_usd"] == "50000000"
  raise "raised serialization" unless values["funds_raised"] == "USD 500,000"
  raise "raised clear" unless PostRevisor.new(post).revise!(actor, { svdex_funds_raised: "" })
  raise "raised not cleared" if topic.reload.custom_fields["svdex_funds_raised"].present?
  raise "clear" unless PostRevisor.new(post).revise!(actor, { svdex_interest_rate: "" })
  raise "rate not cleared" if topic.reload.custom_fields["svdex_interest_rate"].present?
  begin
    DiscourseSvdex.validate_field!("svdex_interest_rate", "x" * 81)
    raise "unbounded interest"
  rescue Discourse::InvalidParameters
  end
  begin
    DiscourseSvdex.validate_field!("svdex_funds_raised", "x" * 81)
    raise "unbounded funds raised"
  rescue Discourse::InvalidParameters
  end
  # Company-wide funding must never be inferred from the current offering.
  raise "Funding was inferred from a round" if topic.custom_fields["svdex_total_funding"].present?
  raise "total funding edit" unless PostRevisor.new(post).revise!(actor, { svdex_total_funding: "USD 12,500,000", svdex_funds_raised: "USD 500,000" })
  topic.reload
  raise "total funding not stored" unless topic.custom_fields["svdex_total_funding"] == "USD 12,500,000"
  raise "round funding was changed" unless topic.custom_fields["svdex_funds_raised"] == "USD 500,000"
  values = TopicViewSerializer.new(TopicView.new(topic.id, actor), scope: actor.guardian, root: false).as_json.fetch(:svdex_listing)
  raise "total funding serialization" unless values["total_funding"] == "USD 12,500,000" && values["funds_raised"] == "USD 500,000"
  raise "total funding clear" unless PostRevisor.new(post).revise!(actor, { svdex_total_funding: "" })
  raise "total funding not cleared" if topic.reload.custom_fields["svdex_total_funding"].present?
  raise "round funding erased" unless topic.custom_fields["svdex_funds_raised"] == "USD 500,000"
  begin
    DiscourseSvdex.validate_field!("svdex_total_funding", "x" * 81)
    raise "unbounded total funding"
  rescue Discourse::InvalidParameters
  end
  { svdex_valuation_cap: "USD 10,000,000", svdex_conversion_discount: "20%", svdex_strike_price: "USD 2.50", svdex_expiration: "2030-06-30" }.each do |key, value|
    raise "Term edit failed" unless PostRevisor.new(post).revise!(actor, { key => value })
    raise "Term was not stored" unless topic.reload.custom_fields[key.to_s] == value
    values = TopicViewSerializer.new(TopicView.new(topic.id, actor), scope: actor.guardian, root: false).as_json.fetch(:svdex_listing)
    raise "Term serialization failed" unless values[key.to_s.delete_prefix("svdex_")] == value
    raise "Term clear failed" unless PostRevisor.new(post).revise!(actor, { key => "" })
    raise "Term was not cleared" if topic.reload.custom_fields[key.to_s].present?
    begin
      DiscourseSvdex.validate_field!(key.to_s, "x" * 81)
      raise "Unbounded term"
    rescue Discourse::InvalidParameters
    end
  end
  puts "PASS financial field creation, independent editing, serialization, clearing and length validation"
  raise ActiveRecord::Rollback
end
