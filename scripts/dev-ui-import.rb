# frozen_string_literal: true
# A warm local-only Rails process. JSON requests select fixed native theme imports;
# they cannot execute Ruby, choose another host, or change content/financial records.
require "json"

$stdout.sync = true
abort "UI development is only for localhost:4080" unless GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"

names = { "sidebar" => "SVDEX Sidebar", "interface" => "SVDEX Interface", "styles" => "SVDEX" }.freeze
paths = { "sidebar" => "/tmp/miscdex-sidebar", "interface" => "/tmp/miscdex-interface" }.freeze
emit = ->(data) { puts "SVDEX_UI_JSON #{JSON.generate(data)}" }

unless names.all? { |key, name| Theme.exists?(name: name, component: key != "styles") }
  abort "Local themes are missing. Run npm run setup first."
end
# Anonymous/background previews otherwise poll every 25/60 seconds. Keep native
# delivery responsive only for this local development session.
polling = %w[polling_interval anon_polling_interval background_polling_interval].to_h { |key| [key, SiteSetting.public_send(key)] }
polling.each_key { |key| SiteSetting.public_send("#{key}=", 1000) }
emit.call(type: "ready")

begin
  STDIN.each_line do |line|
    request = nil
    begin
      request = JSON.parse(line)
      break if request == { "command" => "stop" }
      groups = request.fetch("groups")
      raise "Invalid UI import request" unless request.keys.sort == %w[groups id] && groups.is_a?(Array) && groups.any? && groups.uniq == groups && (groups - names.keys).empty?

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Rails.application.executor.wrap do
        ActiveRecord::Base.transaction do
          groups.each do |key|
            theme = Theme.find_by!(name: names.fetch(key), component: key != "styles")
            if key == "styles"
              theme.set_field(target: :common, name: "scss", value: File.read("/tmp/miscdex-appearance/common.scss"))
              theme.save!
            else
              theme = RemoteTheme.import_theme_from_directory(paths.fetch(key), theme_id: theme.id)
              raise theme.errors.full_messages.join(", ") unless theme.persisted? && theme.errors.empty?
              # Native save hooks rebuild JS only when the module tree changed.
              raise "Theme JavaScript compilation failed" if theme.javascript_cache&.content.to_s.start_with?("throw new Error(")
            end
            failures = theme.theme_fields.filter_map { |field| "#{field.name}: #{field.error}" if field.error.present? }
            raise failures.join("\n") if failures.any?
          end
        end
        # The Docker preview uses a production asset build. Ask the existing native
        # live-development listener to refresh, including for GJS/JS deletions.
        MessageBus.publish("/file-change", ["development-mode-theme-changed"])
      end
      emit.call(type: "updated", id: request.fetch("id"), groups: groups,
                seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3))
    rescue StandardError => error
      emit.call(type: "error", id: request.is_a?(Hash) ? request["id"] : nil, message: error.message)
    end
  end
ensure
  polling.each { |key, value| SiteSetting.public_send("#{key}=", value) if SiteSetting.public_send(key) == 1000 }
end
