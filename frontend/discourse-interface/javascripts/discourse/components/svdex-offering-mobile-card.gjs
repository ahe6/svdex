import Component from "@glimmer/component";
import { service } from "@ember/service";
import BulkSelectCheckbox from "discourse/components/topic-list/bulk-select-checkbox";
import PostCountOrBadges from "discourse/components/topic-list/post-count-or-badges";
import TopicLink from "discourse/components/topic-list/topic-link";
import TopicStatus from "discourse/components/topic-status";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { offeringTerms } from "../lib/svdex-offering-terms";

// Keep the same compact offering preview in dedicated lists and mixed feeds.
// Core still renders desktop and ordinary topics.
export default class OfferingMobileCard extends Component {
  @service site;
  get topic() { return this.args.outletArgs.topic; }
  get visible() { return this.site.mobileView && this.topic.svdex_listing; }
  get termsText() {
    const { primary, secondary } = offeringTerms(this.topic.svdex_listing, this.topic.title);
    return [primary, secondary].filter(Boolean).join(" · ");
  }
  get summary() { return this.topic.svdex_listing.summary; }

  <template>
    {{#if this.visible}}
      <td class="topic-list-data svdex-offering-mobile-cell">
        <article class="svdex-offering-card">
          <div class="user-info small svdex-offering-card__identity">
            {{#if @outletArgs.bulkSelectEnabled}}
              <BulkSelectCheckbox @isSelected={{@outletArgs.isSelected}} @onToggle={{@outletArgs.onBulkSelectToggle}} @topic={{this.topic}} />
            {{else}}
              <div class="user-image"><div class="user-image-inner">
                <DUserLink @username={{this.topic.creator.username}}>{{dAvatar this.topic.creator imageSize="large"}}</DUserLink>
              </div></div>
            {{/if}}
            <div class="user-detail">
              <div class="name-line">
                <TopicStatus @context="topic-list" @topic={{this.topic}} />
                <TopicLink class="name raw-link raw-topic-link" @topic={{this.topic}} />
                {{#if this.topic.unseen}}<span class="badge-notification new-topic"></span>{{/if}}
              </div>
              {{#if this.summary}}<a href={{this.topic.url}} class="svdex-offering-card__summary">{{this.summary}}</a>{{/if}}
            </div>
            <span class="svdex-offering-card__replies"><PostCountOrBadges @postBadgesEnabled={{@outletArgs.showTopicPostBadges}} @topic={{this.topic}} /></span>
          </div>
          <a href={{this.topic.url}} class="topic-excerpt svdex-offering-card__preview">
            {{this.termsText}}
          </a>
          <div class="svdex-offering-card__footer">
            <span class="svdex-offering-card__tags topic-item-stats__category-tags">
              {{#unless @outletArgs.hideCategory}}{{dCategoryLink this.topic.category}}{{/unless}}
              {{dDiscourseTags this.topic mode="list"}}
            </span>
            <a class="age activity" title={{this.topic.bumpedAtTitle}} href={{this.topic.lastPostUrl}}>{{dFormatDate this.topic.bumpedAt format="tiny" noTitle="true"}}</a>
          </div>
        </article>
      </td>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
