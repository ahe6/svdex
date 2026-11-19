# frozen_string_literal: true
DiscourseSvdex::Prototypes::CompanyProfiles.ensure_local!
DiscourseSvdex::Prototypes::CompanyProfiles.setup!
actor = DiscourseSvdex::Prototypes::CompanyCatalog.reviewer!
documents = DiscourseSvdex::Prototypes::CatalogDocument.read_directory("/tmp/svdex-company-catalog-input")
report = DiscourseSvdex::Prototypes::CompanyCatalog.import!(documents, actor: actor, apply: ENV["SVDEX_CATALOG_APPLY"] == "1")
puts JSON.pretty_generate(mode: ENV["SVDEX_CATALOG_APPLY"] == "1" ? "applied" : "preview", companies: report)
