#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "../deploy/discourse/plugins/discourse-svdex/lib/discourse_svdex/prototypes/public_catalog_document"
begin
  data = DiscourseSvdex::Prototypes::PublicCatalogDocument.bundle(File.expand_path("../directory", __dir__))
  if ARGV.first
    text = JSON.generate(data)
    raise DiscourseSvdex::Prototypes::CatalogDocument::Invalid, "Bundle exceeds 16 MB" if text.bytesize > 16 * 1024 * 1024
    File.write(ARGV.fetch(0), text)
  end
  puts "Validated #{data.fetch('entries').length} public content file(s); no application build or database access."
rescue DiscourseSvdex::Prototypes::CatalogDocument::Invalid => error
  abort error.message
end
