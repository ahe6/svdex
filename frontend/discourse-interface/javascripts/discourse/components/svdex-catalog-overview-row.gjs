import { or } from "truth-helpers";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import LatestTopicListItem from "discourse/components/topic-list/latest-topic-list-item";
import { isCategoryListPath, isOfferingCategory } from "../lib/svdex-offering-categories";
import { isProductCatalog } from "../lib/svdex-products";
import { offeringExemption, offeringTerms, topicTermsPreview } from "../lib/svdex-offering-terms";
import { isPresaleCategory, presaleTerms } from "../lib/svdex-presales";
import { OfferingTermDetails } from "./svdex-home-offer-details.gjs";
import ProductUpvote from "./svdex-product-upvote.gjs";

export function isCatalogCategory(category, settings) {
  return isOfferingCategory(category?.id, settings) || isProductCatalog(category?.id, settings);
}

export default <template>
  <td class="topic-list-data svdex-catalog-overview-cell">
    <LatestTopicListItem @topic={{@topic}} />
  </td>
</template>;

class CatalogOverviewOutlet extends Component {
  @service router;
  @service site;
  @service siteSettings;

  get topic() { return this.args.outletArgs.topic; }

  get category() {
    if (this.site.mobileView) return;
    const path = this.router.currentURL.split("?")[0];
    return this.site.categories.find(category =>
      isCatalogCategory(category, this.siteSettings) &&
      isCategoryListPath(category, path)
    );
  }

  get active() { return Boolean(this.category); }

  get dedicatedTerms() {
    const id = this.category?.id;
    return (isOfferingCategory(id, this.siteSettings) && this.topic.svdex_listing) ||
      (isPresaleCategory(id, this.siteSettings) && this.topic.svdex_presale);
  }
}

export class CatalogOverviewTermsHeading extends CatalogOverviewOutlet {
  get showHeading() {
    const id = this.category?.id;
    return !this.args.outletArgs.bulkSelectEnabled &&
      (isOfferingCategory(id, this.siteSettings) || isPresaleCategory(id, this.siteSettings));
  }

  <template>
    {{#if this.showHeading}}
      <span class="svdex-catalog-terms-heading">Terms</span>
    {{/if}}
  </template>
}

export class CatalogOverviewLogo extends CatalogOverviewOutlet {
  <template>
    {{#if this.active}}
      {{#if this.topic.svdex_product.vote}}
        <ProductUpvote @vote={{this.topic.svdex_product.vote}} />
      {{/if}}
      {{#if this.topic.svdex_organization_logo}}
        <div class="topic-poster">
          <img class="avatar svdex-topic-logo" src={{this.topic.svdex_organization_logo}}
            width="48" height="48" alt="" loading="lazy" />
        </div>
      {{/if}}
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}

export class CatalogOverviewPreview extends CatalogOverviewOutlet {
  get summary() {
    return (this.topic.svdex_listing || this.topic.svdex_presale || this.topic.svdex_product)?.summary;
  }

  get terms() { return this.dedicatedTerms ? "" : topicTermsPreview(this.topic, { includeExemption: true }); }

  <template>
    {{#if this.active}}
      {{#if (or this.summary this.terms)}}
        <a class="topic-excerpt svdex-catalog-overview-preview" href={{this.topic.url}}>
          {{#if this.summary}}<span title={{this.summary}}>{{this.summary}}</span>{{/if}}
          {{#if this.terms}}<span>{{this.terms}}</span>{{/if}}
        </a>
      {{/if}}
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}

export class CatalogOverviewTerms extends CatalogOverviewOutlet {
  get terms() {
    const topic = this.topic;
    const terms = topic.svdex_presale
      ? presaleTerms(topic.svdex_presale, { deliveryFirst: true })
      : offeringTerms(topic.svdex_listing, topic.title);
    const exemption = topic.svdex_listing && offeringExemption(topic);
    return { ...terms, secondary: [terms.secondary, exemption].filter(Boolean).join(" · ") };
  }

  get showProgress() { return this.terms.progress !== null; }

  <template>
    {{#if this.dedicatedTerms}}
      <OfferingTermDetails
        class="svdex-catalog-row-terms"
        @terms={{this.terms}}
        @showProgress={{this.showProgress}}
        @singleLineSecondary={{this.topic.svdex_presale}}
      />
    {{/if}}
    {{yield}}
  </template>
}
