import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { resetCachedTopicList } from "discourse/lib/cached-topic-list";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";

export default class ProductUpvote extends Component {
  @service currentUser;
  @service session;
  @service site;
  @tracked pending = false;
  @tracked updatedVote;

  get vote() { return this.updatedVote?.post_id === this.args.vote.post_id ? this.updatedVote : this.args.vote; }
  get count() { return String(this.vote.count ?? 0); }
  get label() { return this.vote.voted ? "Remove product upvote" : "Upvote product"; }
  get accessibleLabel() { return `${this.label} (${this.count})`; }
  get disabled() { return this.pending || !this.vote.can_toggle; }

  @action async toggle() {
    if (!this.currentUser) return DiscourseURL.routeTo("/login");
    const vote = this.vote;
    const type = this.site.post_action_types.find(item => item.name_key === "like")?.id;
    if (!type || this.disabled) return;

    this.pending = true;
    try {
      const response = vote.voted
        ? await ajax(`/post_actions/${vote.post_id}`, { type: "DELETE", data: { post_action_type_id: type } })
        : await ajax("/post_actions", { type: "POST", data: { id: vote.post_id, post_action_type_id: type } });
      const like = response?.actions_summary?.find(item => item.id === type);
      this.updatedVote = {
        post_id: vote.post_id,
        count: like?.count ?? 0,
        voted: Boolean(like?.acted),
        can_toggle: Boolean(like?.acted ? like.can_undo : like?.can_act),
      };
      resetCachedTopicList(this.session);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.pending = false;
    }
  }

  <template>
    <DButton class={{if this.vote.voted "btn-transparent svdex-product-upvote is-voted" "btn-transparent svdex-product-upvote"}}
      @icon="arrow-up" @translatedLabel={{this.count}} @translatedAriaLabel={{this.accessibleLabel}} @translatedTitle={{this.label}}
      @disabled={{this.disabled}} @action={{this.toggle}} aria-pressed={{if this.vote.voted "true" "false"}} />
  </template>
}
