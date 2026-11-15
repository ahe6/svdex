# frozen_string_literal: true
# Shared, non-secret feature defaults. Authorization, intake, credentials, policy
# publication and environment guards deliberately stay in their callers.
module SvdexNativeDefaults
  GROUPS = {
    navigation: { nested_replies_enabled: true, nested_replies_default: true }.freeze,
    events: {
      discourse_events_enabled: true,
      discourse_post_event_enabled: true,
      enable_improved_event_reminders: true,
      sidebar_show_upcoming_events: false,
    }.freeze,
  }.freeze

  def self.apply!(*groups)
    # Validate the whole request before changing any native setting.
    values = groups.map { |group| GROUPS.fetch(group) }.reduce({}, :merge)
    values.each { |name, value| SiteSetting.public_send("#{name}=", value) }
  end
end
