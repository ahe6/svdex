abort "Local only" unless GlobalSetting.hostname == "localhost"
field = DiscourseSvdex::VALUATION_FIELD
category = Category.find(SiteSetting.svdex_public_offerings_category_id)
app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! "localhost"
Middleware::AnonymousCache.disable_anon_cache
Post.transaction do
  token = "Valuation boundary #{SecureRandom.hex(5)}"
  values = [nil, 9_999_999, 10_000_000, 49_999_999, 50_000_000, 249_999_999, 250_000_000]
  topics = values.map.with_index do |value, index|
    opts = { title: "#{token} company #{index}", raw: "Transaction-scoped valuation check.", category: category.id, skip_validations: true, skip_jobs: true }
    opts[field.to_sym] = value.to_s if value
    PostCreator.create!(Discourse.system_user, **opts).topic
  end
  { "undisclosed" => [0], "under-10m" => [1], "10m-50m" => [2, 3], "50m-250m" => [4, 5], "250m-plus" => [6] }.each do |range, indices|
    app.get "#{category.url}.json", params: { svdex_company: token, svdex_valuation: range }
    raise "HTTP #{app.response.status}" unless app.response.status == 200
    ids = JSON.parse(app.response.body).fetch("topic_list").fetch("topics").map { |t| t["id"] }.sort
    raise "#{range}: #{ids} expected #{indices.map { |i| topics[i].id }} values #{topics.map { |t| [t.id,t.custom_fields] }}" unless ids == indices.map { |i| topics[i].id }.sort
  end
  PostRevisor.new(topics[1].first_post).revise!(Discourse.system_user, { field.to_sym => "60000000" })
  raise "edit failed" unless topics[1].reload.custom_fields[field] == 60_000_000
  PostRevisor.new(topics[1].first_post).revise!(Discourse.system_user, { field.to_sym => "" })
  raise "clear failed" if topics[1].reload.custom_fields[field].present?
  ["-1", "abc", "1.5", "9007199254740992", 0].each do |value|
    begin
      DiscourseSvdex.validate_field!(field, value)
      raise "accepted invalid #{value}"
    rescue Discourse::InvalidParameters
    end
  end
  app.get "#{category.url}.json", params: { svdex_valuation: "invalid" }
  raise "unknown filter accepted" unless app.response.status == 400
  puts "PASS valuation range boundaries, create/edit/clear, invalid inputs and invalid filters"
  raise ActiveRecord::Rollback
end
