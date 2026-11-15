export function needsEventBuilder(options, settings, currentUser) {
  return Boolean(settings.discourse_post_event_enabled && currentUser?.can_create_discourse_post_event &&
    Number(settings.svdex_events_category_id) > 0 && Number(options.category?.id) === Number(settings.svdex_events_category_id) &&
    !options.body && !options.draft);
}
