import { usesSectorFilter, isOverviewDirectory } from "../lib/svdex-sector-navigation";
import { isOfferingCategory } from "../lib/svdex-offering-categories";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import HomeFiltersModal from "./svdex-home-filters-modal.gjs";
import { activeFilterCount } from "../lib/svdex-mobile-filters";
import DButton from "discourse/ui-kit/d-button";

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
    return activeFilterCount(this.router.currentRoute?.queryParams, this.args.outletArgs.tag, this.args.outletArgs.additionalTags);
  }
  get active() { return this.count > 0; }
  get title() { return this.active ? `Filters (${this.count} active)` : "Filters"; }
  @action open() {
    this.modal.show(HomeFiltersModal, { model: { ...this.args.outletArgs, isOffering: this.isOffering, homeFeed: this.homeFeed } });
  }
  <template>
    {{#if this.visible}}
      <span class={{if this.homeFeed "svdex-mobile-filters svdex-home-filters" "svdex-mobile-filters"}}>
        <DButton @icon="angle-right" @translatedLabel="Filter" @translatedTitle={{this.title}} @translatedAriaLabel={{this.title}} class={{if this.active "btn-primary svdex-filter-trigger" "btn-default svdex-filter-trigger"}} @action={{this.open}} />
      </span>
    {{/if}}
  </template>
}
