# frozen_string_literal: true

# Targeted native setting/theme update; never copies local event topics or data.
abort "Explicit production Events setup required" unless GlobalSetting.hostname == "svdex.com" && ENV["SVDEX_ENABLE_EVENTS"] == "1"

theme = Theme.find_by!(name: "SVDEX Sidebar", component: true)
field = theme.theme_fields.find { |entry| entry.value.to_s.include?("class extends UsersSectionLink") }
raise "Expected one sidebar initializer" unless field
anchor = "  api.addCommunitySectionLink(() => class extends UsersSectionLink {"
addition = <<~JS
  // Native sidebar link and native event directory; only its label/position differ.
  api.addCommunitySectionLink(BaseLink => class extends BaseLink {
    get name() { return "svdex-events"; }
    get text() { return "Events"; }
    get title() { return "Upcoming events"; }
    get route() { return "discourse-post-event-upcoming-events"; }
    get prefixValue() { return "calendar-day"; }
    get shouldDisplay() { return this.siteSettings.discourse_events_enabled && this.siteSettings.discourse_post_event_enabled; }
  });
JS
already_present = field.value.include?('return "svdex-events"')
raise "Sidebar anchor changed" unless already_present || field.value.scan(anchor).length == 1
settings = %i[discourse_events_enabled discourse_post_event_enabled discourse_post_event_allowed_on_groups sidebar_show_upcoming_events enable_improved_event_reminders]
backup = "/shared/svdex-auth/events-rollback.json"
unless File.exist?(backup)
  File.open(backup, File::WRONLY | File::CREAT | File::EXCL, 0600) do |file|
    file.write(JSON.generate(settings: settings.to_h { |key| [key, SiteSetting.public_send(key)] }, theme_id: theme.id, field_id: field.id, value: field.value))
  end
end

ActiveRecord::Base.transaction do
  unless already_present
    value = field.value.sub(anchor, addition.lines.map { |line| "  #{line}" }.join + "\n" + anchor)
    theme.set_field(target: Theme.targets.key(field.target_id), name: field.name, type_id: field.type_id, value: value)
    theme.save!
    raise "Theme compilation failed" if theme.errors.present? || theme.theme_fields.reload.any? { |entry| entry.error.present? }
  end
  SiteSetting.discourse_events_enabled = true
  SiteSetting.discourse_post_event_enabled = true
  SiteSetting.discourse_post_event_allowed_on_groups = "1|2|10"
  SiteSetting.enable_improved_event_reminders = true
  SiteSetting.sidebar_show_upcoming_events = false
end
puts "Native Events enabled, member creation enabled; sidebar link added. No topics or users imported."
