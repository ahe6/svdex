import Component from "@glimmer/component";
import { service } from "@ember/service";
import { homeOfferFigures } from "../lib/svdex-home-offer-figures";

export default class ListingHomePreview extends Component {
  @service site;
  get topic() { return this.args.outletArgs.topic; }
  get data() { return this.topic.svdex_listing; }
  get visible() { return Boolean(this.data); }
  get summary() {
    // Pinned topics can already have core's excerpt; do not print it twice.
    return this.args.outletArgs.expandPinned && this.topic.hasExcerpt ? "" : this.data?.summary?.trim();
  }
  get details() {
    // Desktop already shows the key figures in its financial column. Mobile
    // has no such column, so repeat only those same key figures as plain text.
    if (!this.site.mobileView || !this.data) return "";
    return homeOfferFigures(this.data).map(({ label, value }) => `${label}: ${value}`).join(", ");
  }

  <template>
    {{#if this.visible}}
      {{#if this.summary}}
        <a class="topic-excerpt svdex-home-listing-preview" href={{this.topic.url}}>
          <span class="svdex-home-listing-summary" title={{this.summary}}>{{this.summary}}</span>
          {{#if this.details}}<br /><span class="svdex-home-listing-secondary" title={{this.details}}>{{this.details}}</span>{{/if}}
        </a>
      {{else if this.details}}
        <a class="topic-excerpt svdex-home-listing-preview svdex-home-listing-secondary" href={{this.topic.url}} title={{this.details}}>{{this.details}}</a>
      {{/if}}
    {{/if}}
  </template>
}
