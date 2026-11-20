# frozen_string_literal: true
DiscourseSvdex::Prototypes::CompanyProfiles.ensure_local!
id = ENV.fetch("SVDEX_CORRECTION_TOPIC")
raise "Invalid correction topic" unless id.match?(/\A[1-9]\d*\z/)
actor = DiscourseSvdex::Prototypes::CompanyCatalog.reviewer!
topic = Topic.find(id)
document = DiscourseSvdex::Prototypes::CompanyCatalog.proposal_document!(topic, actor)
File.write("/tmp/svdex-company-correction.json", JSON.pretty_generate(document) + "\n")
puts "Prepared a proposed public-data file; no company facts or repository files were changed."
