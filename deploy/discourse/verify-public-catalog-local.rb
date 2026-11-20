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
  company_tag = sync.tag!("issuer-#{suffix}", "Companies")
  issuer = model.create!(name: "Research issuer", slug: "issuer-#{suffix}", kind: "companies", listed: true,
    facts: { "company_tag_id" => company_tag.id })
  product = document.call("products", {"description" => "Product information and background for research teams.", "status" => "launched", "company_tag" => company_tag.name})
  security = document.call("securities", {"description" => "Public terms for a research company debt instrument.", "instrument_type" => "debt", "interest_rate" => "8% per year"}).merge("tag" => nil)
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
  directory_product = DiscourseSvdex::ProductDirectory.new(search: topic.title).payload.fetch(:products).find { |row| row[:id] == topic.id }
  catalog_assert!(directory_product[:company] == { name: issuer.name, url: issuer.profile_url } && topic.tags.exists?(name: product["tag"]), "reviewed products link to their company and keep their own product tag")
  view = TopicViewSerializer.new(TopicView.new(topic.id, nil), scope: Guardian.new, root: false).as_json
  catalog_assert!(view[:svdex_catalog_product_id] == product["id"], "product topics expose the ID of their reviewed directory file")
  reply = PostCreator.create!(actor, topic_id: topic.id, raw: "A discussion reply that must survive catalog corrections.", skip_validations: true, skip_jobs: true)
  bumped_at = topic.reload.bumped_at
  changed = Marshal.load(Marshal.dump(bundle))
  changed["entries"].last["document"]["name"] = "Updated research product #{suffix}"
  sync.import!(changed, actor: actor, apply: true)
  catalog_assert!(topic.reload.title.start_with?("Updated research product") && Post.exists?(reply.id) && topic.bumped_at == bumped_at, "product corrections use native revisions and preserve replies and activity order")
  reverted = sync.import!(bundle, actor: actor, apply: true)
  catalog_assert!(reverted.last[:changed] && topic.reload.title == product["name"], "reverting a reviewed file restores its earlier product content")
  security_bundle = ->(doc) { bundle.merge("entries" => [{"kind" => "securities", "document" => doc}]) }
  category = DiscourseSvdex::SecuritiesDirectory.public_category
  existing = PostCreator.create!(actor, title: "Security topic #{suffix}", raw: "Existing public offering topic and conversation.", category: category.id, skip_validations: true, skip_jobs: true).topic
  existing_reply = PostCreator.create!(actor, topic_id: existing.id, raw: "A reply that should remain on the existing public offering.", skip_validations: true, skip_jobs: true)
  security["facts"]["topic_id"] = existing.id
  entries = security_bundle.call(security)
  catalog_assert!(sync.import!(entries, actor: actor).first[:changed] && existing.reload.title.start_with?("Security topic"), "security preview does not modify the native topic")
  sync.import!(entries, actor: actor, apply: true)
  existing.reload
  security_view = TopicViewSerializer.new(TopicView.new(existing.id, nil), scope: Guardian.new, root: false).as_json
  catalog_assert!(security_view[:svdex_catalog_security_id] == security["id"] && Post.exists?(existing_reply.id), "reviewed public securities preserve native discussion and expose their file ID")
  catalog_assert!(!sync.import!(entries, actor: actor, apply: true).first[:changed], "unchanged securities sync is idempotent")
  security["facts"]["interest_rate"] = "9% per year"
  sync.import!(entries, actor: actor, apply: true)
  catalog_assert!(existing.reload.custom_fields["svdex_interest_rate"] == "9% per year", "reviewed financial field changes sync independently of the topic text")
  security["facts"].delete("interest_rate")
  sync.import!(entries, actor: actor, apply: true)
  catalog_assert!(existing.reload.custom_fields["svdex_interest_rate"].nil?, "removing a reviewed term clears it from the offering")
  catalog_assert!(!sync.import!(entries, actor: actor, apply: true).first[:changed], "cleared terms stay clear on repeated imports")
  begin
    new_security = security.merge("id" => "security-new-#{suffix}", "facts" => security["facts"].except("topic_id"))
    sync.import!(security_bundle.call(new_security), actor: actor, apply: true)
    raise "GitHub created an offering"
  rescue DiscourseSvdex::Prototypes::CatalogDocument::Invalid
    puts "PASS the reviewed catalog requires an offering already created on SVDEX"
  end
  restricted = PostCreator.create!(actor, title: "Restricted security #{suffix}", raw: "A restricted topic never eligible for the public GitHub catalog.", category: SiteSetting.svdex_private_offerings_category_id, skip_validations: true, skip_jobs: true).topic
  begin
    invalid = security.merge("id" => "security-private-#{suffix}", "facts" => security["facts"].merge("topic_id" => restricted.id))
    sync.import!(security_bundle.call(invalid), actor: actor, apply: true)
    raise "Restricted security accepted"
  rescue DiscourseSvdex::Prototypes::CatalogDocument::Invalid
    puts "PASS the public catalog rejects a private security topic even for a staff reviewer"
  end
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
