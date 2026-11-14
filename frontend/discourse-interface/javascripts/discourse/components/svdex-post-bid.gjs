import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import OfferingBidModal from "./svdex-offering-bid.gjs";

export default class PostBid extends Component {
  static shouldRender({ post }) {
    return post.post_number === 1 && !post.deleted_at && !post.hidden && Boolean(post.topic?.svdex_listing?.interest_organization);
  }
  @service modal;
  @service currentUser;
  @service siteSettings;
  @action open() {
    const topic = this.args.post.topic;
    this.modal.show(OfferingBidModal, { model: {
      topicId: topic.id,
      topicTitle: topic.title,
      closed: topic.closed || topic.archived,
    } });
  }
  <template>
    {{#if this.currentUser}}{{#if this.siteSettings.svdex_bids_enabled}}
      <DButton ...attributes class="post-action-menu__svdex-bid btn-primary" @translatedLabel="Submit bid" @translatedAriaLabel="Submit bid" @translatedTitle="Submit bid" @action={{this.open}} />
    {{/if}}{{/if}}
  </template>
}
