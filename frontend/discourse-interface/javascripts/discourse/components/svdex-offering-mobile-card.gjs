import Component from "@glimmer/component";
import { service } from "@ember/service";
import BulkSelectCheckbox from "discourse/components/topic-list/bulk-select-checkbox";
import PostCountOrBadges from "discourse/components/topic-list/post-count-or-badges";
import TopicLink from "discourse/components/topic-list/topic-link";
import TopicStatus from "discourse/components/topic-status";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { isCategoryListPath, isOfferingCategory } from "../lib/svdex-offering-categories";
import { isProductCategory } from "../lib/svdex-products";
import { topicTermsPreview } from "../lib/svdex-offering-terms";
import ProductUpvote from "./svdex-product-upvote.gjs";

// Keep the same compact offering preview in dedicated lists and mixed feeds.
// Core still renders desktop and ordinary topics.
export default class OfferingMobileCard extends Component {
  @service site;
  @service siteSettings;
  @service router;
  get topic() { return this.args.outletArgs.topic; }
  get data() { return this.topic.svdex_listing || this.topic.svdex_presale || this.topic.svdex_product; }
  get visible() { return this.site.mobileView && this.data; }
  get onOfferingsPage() {
    if (!this.topic.svdex_listing) return false;
    const path = this.router.currentURL.split("?")[0];
    return this.site.categories.some(category => isOfferingCategory(category.id, this.siteSettings) && isCategoryListPath(category, path));
  }
  get termsText() { return topicTermsPreview(this.topic, { includeExemption: this.onOfferingsPage }); }
  get summary() { return this.data?.summary; }
  get productVote() {
    const vote = this.topic.svdex_product?.vote;
    if (!vote) return;
    const path = this.router.currentURL.split("?")[0];
    if (this.site.categories.some(category => isProductCategory(category.id, this.siteSettings) && isCategoryListPath(category, path))) return vote;
  }

  <template>
    {{#if this.visible}}
      <td class="topic-list-data svdex-offering-mobile-cell">
        <article class="svdex-offering-card">
          <div class="user-info small svdex-offering-card__identity">
            {{#if @outletArgs.bulkSelectEnabled}}
              <BulkSelectCheckbox @isSelected={{@outletArgs.isSelected}} @onToggle={{@outletArgs.onBulkSelectToggle}} @topic={{this.topic}} />
            {{else}}
              {{#if this.productVote}}
                <ProductUpvote @vote={{this.productVote}} />
              {{/if}}
              {{#if this.topic.svdex_organization_logo}}
                <div class="user-image">
                  <div class="user-image-inner">
                    <img class="avatar svdex-topic-logo" src={{this.topic.svdex_organization_logo}} width="48" height="48" alt="" loading="lazy" />
                  </div>
                </div>
              {{/if}}
            {{/if}}
            <div class="user-detail">
              <div class="name-line">
                <span class="name-wrapper">
                  <TopicStatus @context="topic-list" @topic={{this.topic}} />
                  <TopicLink class="name raw-link raw-topic-link" @topic={{this.topic}} />
                  {{#if this.topic.unseen}}<span class="badge-notification new-topic"></span>{{/if}}
                </span>
                {{#if this.summary}}
                  <a href={{this.topic.url}} class="svdex-offering-card__summary">{{this.summary}}</a>
                {{/if}}
              </div>
            </div>
            <span class="svdex-offering-card__replies"><PostCountOrBadges @postBadgesEnabled={{@outletArgs.showTopicPostBadges}} @topic={{this.topic}} /></span>
          </div>
          {{#if this.termsText}}
            <a href={{this.topic.url}} class="topic-excerpt svdex-offering-card__preview">{{this.termsText}}</a>
          {{/if}}
          <div class="svdex-offering-card__footer">
            <span class="svdex-offering-card__tags topic-item-stats__category-tags">
              {{#unless this.onOfferingsPage}}
                {{#unless @outletArgs.hideCategory}}{{dCategoryLink this.topic.category}}{{/unless}}
                {{dDiscourseTags this.topic mode="list"}}
              {{/unless}}
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
