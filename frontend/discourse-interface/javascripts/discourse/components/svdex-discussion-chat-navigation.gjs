import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Navigation from "discourse/components/discovery/navigation";

export default class DiscussionChatNavigation extends Component {
  @service router;
  @service site;
  @service siteSettings;
  @service composer;
  get visible() {
    const lounge = this.siteSettings.svdex_lounge_channel_url;
    return lounge && this.router.currentURL?.split("?")[0] === lounge;
  }
  get category() { return this.site.categories.find(c => c.slug === "discussion"); }
  @action createTopic() { this.composer.openNewTopic({ category: this.category }); }
  <template>
    {{#if this.visible}}{{#if this.category}}
      <div class="list-controls svdex-discussion-chat-navigation">
        <Navigation @category={{this.category}} @filterType="chat" @createTopic={{this.createTopic}} />
      </div>
    {{/if}}{{/if}}
  </template>
}
