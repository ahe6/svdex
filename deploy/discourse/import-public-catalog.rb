# frozen_string_literal: true
# Installed with reviewed application code; delivered bundles contain data only.
require "json"
require "digest"
expected = ENV.fetch("SVDEX_CATALOG_HOSTNAME")
abort "Catalog target mismatch" unless GlobalSetting.hostname == expected && %w[localhost staging.svdex.com svdex.com].include?(expected)
abort "Catalog backend is not installed; release independent profiles first" unless defined?(DiscourseSvdex::Prototypes::PublicCatalog)
path = ENV.fetch("SVDEX_CATALOG_BUNDLE")
abort "Catalog bundle too large" unless File.size(path) <= 16 * 1024 * 1024
actor = User.find_by_username(SiteSetting.svdex_private_access_contact)
text = File.read(path)
bundle = JSON.parse(text, object_class: DiscourseSvdex::Prototypes::CatalogDocument::UniqueKeys, max_nesting: 20)
report = DiscourseSvdex::Prototypes::PublicCatalog.import!(bundle, actor: actor, apply: ENV["SVDEX_CATALOG_APPLY"] == "1")
puts JSON.generate(mode: ENV["SVDEX_CATALOG_APPLY"] == "1" ? "applied" : "preview", records: report.size, changed: report.count { |item| item[:changed] }, sha256: Digest::SHA256.hexdigest(text))
