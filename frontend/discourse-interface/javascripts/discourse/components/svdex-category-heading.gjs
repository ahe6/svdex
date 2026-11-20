import Component from "@glimmer/component";
import { service } from "@ember/service";
import { catalogTitle } from "../lib/svdex-feed-views";

export default class CategoryHeading extends Component {
  @service site;
  @service siteSettings;
  @service router;
  @service("svdex-product-directory") directory;

  get category() { return this.args.outletArgs.category; }
  get title() { return catalogTitle(this.category, this.siteSettings); }
  get separateMobileHeading() { return ["Products", "Events"].includes(this.title); }
  get directoryView() { return this.router.currentRoute?.queryParams.svdex_view === "directory"; }

  get count() {
    const route = this.router.currentRoute;
    if (this.directoryView && ["Products", "Pre-sales"].includes(this.title)) {
      const scope = this.title === "Pre-sales" ? "presales" : "products";
      return this.directory.scope === scope ? this.directory.total : null;
    }
    if (this.title === "Events" && route?.name.startsWith("discourse-post-event-upcoming-events")) {
      return this.category.topic_count;
    }
    const list = route?.attributes?.list?.topic_list;
    return list?.svdex_offering_count ?? list?.svdex_catalog_count;
  }
  get showCount() { return Number.isInteger(this.count); }
  get countUnit() { return this.count === 1 ? "item" : "items"; }
  get countsOpenItems() { return this.title === "Offerings" || (this.title === "Pre-sales" && !this.directoryView); }

  get label() {
    return this.category?.name || this.args.outletArgs.tag?.name;
  }

  <template>
    {{#if this.title}}
      <div class="svdex-catalog-heading {{if this.separateMobileHeading "svdex-catalog-heading--separate-mobile"}}">
        <h2>{{this.title}}</h2>
        {{#if this.showCount}}
          <span class="svdex-directory-heading-count">{{this.count}}<span class="sr-only">{{if this.countsOpenItems " open"}} {{this.countUnit}}</span></span>
        {{/if}}
      </div>
    {{else if this.site.mobileView}}
      {{#if this.label}}<div class="svdex-mobile-heading-row"><h2 class="svdex-mobile-category-heading">{{this.label}}</h2></div>{{/if}}
    {{/if}}
  </template>
}
