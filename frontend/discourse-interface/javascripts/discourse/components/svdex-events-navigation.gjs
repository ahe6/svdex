import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Navigation from "discourse/components/discovery/navigation";

export default class EventsNavigation extends Component {
  @service router;
  @service composer;
  @service site;
  @service siteSettings;
  get visible() { return this.router.currentRouteName?.startsWith("discourse-post-event-upcoming-events"); }
  get category() { return this.site.categories.find(c => Number(c.id) === Number(this.siteSettings.svdex_events_category_id)); }
  @action createTopic() { this.composer.openNewTopic({ category: this.category }); }
  <template>
    {{#if this.visible}}{{#if this.category}}
      <div class="list-controls"><Navigation @category={{this.category}} @filterType="svdex-events-calendar" @createTopic={{this.createTopic}} /></div>
    {{/if}}{{/if}}
  </template>
}
