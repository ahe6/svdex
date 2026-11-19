# frozen_string_literal: true
require_relative "../deploy/discourse/plugins/discourse-svdex/lib/discourse_svdex/prototypes/catalog_document"
begin
  docs = DiscourseSvdex::Prototypes::CatalogDocument.read_directory(File.expand_path("../directory/companies", __dir__))
  puts "Validated #{docs.length} public company file(s). No database access required."
rescue DiscourseSvdex::Prototypes::CatalogDocument::Invalid => error
  abort error.message
end
