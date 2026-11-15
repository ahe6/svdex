import test from 'node:test';
import assert from 'node:assert/strict';
import { needsEventBuilder } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-new-event.js';
const settings = { discourse_post_event_enabled: true, svdex_events_category_id: 124 };
const user = { can_create_discourse_post_event: true };
test('new event starts with a date builder without reopening it for calendar selections or drafts', () => {
  assert.equal(needsEventBuilder({category:{id:124}}, settings, user), true);
  for (const options of [{category:{id:5}}, {category:{id:124}, body:'[event start="2026-11-20"][/event]'}, {category:{id:124}, draft:{id:1}}]) {
    assert.equal(needsEventBuilder(options, settings, user), false);
  }
  assert.equal(needsEventBuilder({category:{id:124}}, settings, null), false);
  assert.equal(needsEventBuilder({category:{id:124}}, {...settings,discourse_post_event_enabled:false}, user), false);
});
