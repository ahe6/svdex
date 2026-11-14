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
    return !this.homeFeed && this.site.mobileView && Boolean(this.args.outletArgs.category || this.args.outletArgs.tag);
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
    this.modal.show(HomeFiltersModal, { model: { ...this.args.outletArgs, isOffering: this.isOffering } });
  }
  <template>
    {{#if this.visible}}
      <span class={{if this.homeFeed "svdex-mobile-filters svdex-home-filters" "svdex-mobile-filters"}}>
        <DButton @icon="filter" @translatedTitle={{this.title}} @translatedAriaLabel={{this.title}} class={{if this.active "btn-primary" "btn-default"}} @action={{this.open}} />
      </span>
    {{/if}}
  </template>
}
