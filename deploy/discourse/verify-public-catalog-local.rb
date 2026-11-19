# frozen_string_literal: true
abort "Local only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
model = DiscourseSvdex::Prototypes::CompanyProfileRecord
DiscourseSvdex::Prototypes::CompanyProfiles.setup!
sync = DiscourseSvdex::Prototypes::PublicCatalog
actor = User.find_by!(username: "svdex")
def catalog_assert!(value, message)
  raise message unless value
  puts "PASS #{message}"
end
model.transaction do
  suffix = SecureRandom.hex(5)
  base = { "schema_version" => 1, "summary" => "Research infrastructure and public information.", "sector" => nil, "location" => "United States", "sources" => [{"url" => "https://example.org/research", "note" => "Public research source"}] }
  document = ->(kind, facts) { base.merge("id" => "#{kind}-#{suffix}", "name" => "Research #{kind} #{suffix}", "tag" => "#{kind}-#{suffix}", "facts" => facts) }
  fund = document.call("funds", {"strategy_focus" => "VC", "aum_usd" => 12_000_000, "facts_as_of" => Date.current.iso8601, "source_url" => "https://example.org/research"})
  person = document.call("people", {"role" => "Partner", "focus" => "Research"})
  product = document.call("products", {"description" => "Product information and background for research teams.", "status" => "launched"})
  bundle = { "format" => DiscourseSvdex::Prototypes::PublicCatalogDocument::FORMAT, "entries" => [["funds",fund],["people",person],["products",product]].map { |kind,doc| {"kind" => kind,"document" => doc} } }
  before = [model.count, Tag.count, Topic.count, User.count]
  catalog_assert!(sync.import!(bundle, actor: actor).all? { |r| r[:changed] } && before == [model.count, Tag.count, Topic.count, User.count], "preview validates all entity kinds without persistent profiles, tags, topics or accounts")
  catalog_assert!(sync.import!(bundle, actor: actor, apply: true).size == 3, "one reviewed bundle imports funds, people and native product topics")
  catalog_assert!(sync.import!(bundle, actor: actor, apply: true).none? { |r| r[:changed] }, "unchanged content sync is idempotent")
  f = model.find_by!(catalog_key: "funds/#{fund['id']}")
  p = model.find_by!(catalog_key: "people/#{person['id']}")
  catalog_assert!(f.listed && f.facts["aum_usd"] == 12_000_000 && p.facts["role"] == "Partner" && User.count == before.last, "reviewed facts publish without manufacturing login accounts")
  url = DiscourseSvdex::Prototypes::CompanyProfiles.payload(p, Guardian.new)[:topics_url]
  catalog_assert!(url.present?, "reviewed person identity has a stable public related-topic tag")
  topic = TopicCustomField.find_by!(name: sync::PRODUCT_KEY, value: product["id"]).topic
  reply = PostCreator.create!(actor, topic_id: topic.id, raw: "A discussion reply that must survive catalog corrections.", skip_validations: true, skip_jobs: true)
  bumped_at = topic.reload.bumped_at
  changed = Marshal.load(Marshal.dump(bundle))
  changed["entries"].last["document"]["name"] = "Updated research product #{suffix}"
  sync.import!(changed, actor: actor, apply: true)
  catalog_assert!(topic.reload.title.start_with?("Updated research product") && Post.exists?(reply.id) && topic.bumped_at == bumped_at, "product corrections use native revisions and preserve replies and activity order")
  reverted = sync.import!(bundle, actor: actor, apply: true)
  catalog_assert!(reverted.last[:changed] && topic.reload.title == product["name"], "reverting a reviewed file restores its earlier product content")
  p.update!(summary: "A concurrent database edit that must not be overwritten.")
  conflict = Marshal.load(Marshal.dump(bundle))
  conflict["entries"].first["document"]["name"] = "Must roll back with the conflicting person"
  begin
    sync.import!(conflict, actor: actor, apply: true)
    raise "Conflicting edit was accepted"
  rescue DiscourseSvdex::Prototypes::CatalogDocument::Invalid
    catalog_assert!(f.reload.name == fund["name"], "a database conflict rolls back the entire content batch")
  end
  p.update!(summary: person["summary"])
  topic.custom_fields["svdex_presale_price"] = "$999"
  topic.save_custom_fields
  begin
    sync.import!(bundle, actor: actor, apply: true)
    raise "Conflicting product terms were overwritten"
  rescue DiscourseSvdex::Prototypes::CatalogDocument::Invalid
    puts "PASS manual product terms cannot be silently overwritten by a sync"
  end
  catalog_assert!(sync.import!({"format" => bundle["format"], "entries" => [bundle["entries"].first]}, actor: actor, apply: true).size == 1 && model.exists?(p.id), "removing a file from a bundle never deletes another profile")
  raise ActiveRecord::Rollback
end
puts "Public catalog checks complete; all scenario records rolled back."
