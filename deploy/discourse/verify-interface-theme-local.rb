# Exercise native theme compilation and export/import without touching site data.
abort "Local verification only" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
require "digest"
require "theme_store/zip_exporter"
def assert_interface!(condition, message)
  raise message unless condition
  puts "PASS #{message}"
end
interface = Theme.find_by!(name: "SVDEX Interface", component: true)
assert_interface!(Theme.find(SiteSetting.default_theme_id).child_theme_ids.include?(interface.id), "native Interface component is attached to the active theme")
source = "/tmp/miscdex-interface"
files = Dir.glob("#{source}/javascripts/**/*").select { |p| File.file?(p) }
assert_interface!(files.any?, "interface source includes native theme JavaScript modules")
Theme.transaction do
  ThemeStore::ZipExporter.new(interface).with_export_dir do |folder|
    files.each do |path|
      relative = path.delete_prefix("#{source}/")
      assert_interface!(File.file?("#{folder}/#{relative}") && Digest::SHA256.file(path).hexdigest == Digest::SHA256.file("#{folder}/#{relative}").hexdigest, "native theme export preserves #{relative}")
    end
    restored = RemoteTheme.import_theme_from_directory(folder)
    assert_interface!(restored.persisted? && restored.errors.empty?, "exported interface imports through native theme tools")
    restored.update_javascript_cache!
    js = restored.javascript_cache&.content.to_s
    assert_interface!(js.present? && !js.start_with?("throw new Error("), "restored interface compiles with the native theme compiler")
    # Lounge and event creation reuse bundled, official Chat and Events components. Keep the
    # portability guard against dependencies on any custom plugin asset bundle.
    assert_interface!((restored.javascript_cache.external_plugin_imports - ["chat", "discourse-events"]).empty?, "interface depends only on official Chat/Events assets, never custom plugin bundles")
  end
  raise ActiveRecord::Rollback
end
assert_interface!(Theme.where(name: "SVDEX Interface").count == 1, "theme round-trip leaves no extra installed components")
