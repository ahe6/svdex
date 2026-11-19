import { usesSectorFilter, isOverviewDirectory } from "../lib/svdex-sector-navigation";
import { isOfferingCategory } from "../lib/svdex-offering-categories";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import HomeFiltersModal from "./svdex-home-filters-modal.gjs";
import { activeFilterCount } from "../lib/svdex-mobile-filters";
import { isProductCatalog, productFilterValue } from "../lib/svdex-products";
import FilterTrigger from "./svdex-filter-trigger.gjs";

export default class ListingMobileFilters extends Component {
  @service modal;
  @service router;
  @service site;
  @service siteSettings;
  get isOffering() {
    return isOfferingCategory(this.args.outletArgs.category?.id, this.siteSettings);
  }
  get visible() {
    if (isOverviewDirectory(this.router.currentRouteName) || this.router.currentRouteName?.startsWith("chat")) return false;
    const args = this.args.outletArgs;
    if (this.siteSettings.tagging_enabled && usesSectorFilter(args.category, args.tag, this.router.currentRouteName, this.siteSettings)) return false;
    return this.homeFeed || Boolean(args.category || args.tag);
  }
  get homeFeed() {
    const homeFeed = !this.args.outletArgs.category && !this.args.outletArgs.tag &&
      /^discovery\.(latest|top|overview)(?:\.|$)/.test(this.router.currentRouteName);
    return homeFeed;
  }
  get count() {
    const typeActive = isProductCatalog(this.args.outletArgs.category?.id, this.siteSettings) && productFilterValue(this.args.outletArgs.category?.id, this.router.currentURL, this.siteSettings) !== "all";
    return activeFilterCount(this.router.currentRoute?.queryParams, this.args.outletArgs.tag, this.args.outletArgs.additionalTags) + Number(typeActive);
  }
  get active() { return this.count > 0; }
  @action open() {
    this.modal.show(HomeFiltersModal, { model: { ...this.args.outletArgs, isOffering: this.isOffering, homeFeed: this.homeFeed } });
  }
  <template>
    {{#if this.visible}}
      <span class={{if this.homeFeed "svdex-mobile-filters svdex-home-filters" "svdex-mobile-filters"}}>
        <FilterTrigger @active={{this.active}} @count={{this.count}} @action={{this.open}} />
      </span>
    {{/if}}
  </template>
}
