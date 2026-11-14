# Native local component import; does not touch content, membership or fields.
abort "Interface installation is only for localhost:4080" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
existing = Theme.find_by(name: "SVDEX Interface", component: true)
component = RemoteTheme.import_theme_from_directory("/tmp/miscdex-interface", theme_id: existing&.id)
raise component.errors.full_messages.join(", ") unless component.persisted? && component.errors.empty?
parent = Theme.find(SiteSetting.default_theme_id)
parent.child_theme_ids = (parent.child_theme_ids + [component.id]).uniq
parent.save!
component.update_javascript_cache!
raise "Interface JavaScript compilation failed" if component.javascript_cache&.content.to_s.start_with?("throw new Error(")
raise "Interface fields contain compilation errors" if component.theme_fields.any? { |field| field.error.present? }
puts "Installed native SVDEX Interface component #{component.id} on #{parent.name}."
