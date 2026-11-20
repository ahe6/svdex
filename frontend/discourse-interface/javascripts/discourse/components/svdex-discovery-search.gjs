import { isPresaleCategory } from "../lib/svdex-presales";
import { isProductCategory } from "../lib/svdex-products";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { tracked } from "@glimmer/tracking";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DiscourseURL from "discourse/lib/url";
import { isOfferingCategory } from "../lib/svdex-offering-categories";

export default class DiscoverySearch extends Component {
  @service router;
  @service site;
  @service siteSettings;
  @tracked query = this.committedSearch;
  get committedSearch() { return this.router.currentRoute?.queryParams?.search || ""; }
  @action syncSearch() { this.query = this.committedSearch; }
  get category() { return this.args.outletArgs.category; }
  get visible() {
    if (this.args.panel) return true;
    return !this.site.mobileView && !isOfferingCategory(this.category?.id, this.siteSettings) &&
      !/overview|forums|categories/.test(this.router.currentRouteName || "") &&
      (this.router.currentRouteName?.startsWith("discovery.") || (this.category && this.router.currentRouteName?.startsWith("tags.")) || this.router.currentRouteName?.startsWith("discourse-post-event-upcoming-events"));
  }
  get placeholder() {
    if (isProductCategory(this.category?.id, this.siteSettings)) return "Search products";
    if (isPresaleCategory(this.category?.id, this.siteSettings)) {
      return this.router.currentRoute?.queryParams.svdex_view === "directory" ? "Search products" : "Search pre-sales";
    }
    return Number(this.category?.id) === Number(this.siteSettings.svdex_events_category_id) ? "Search events" : "Search topics";
  }
  @action update(event) { this.query = event.target.value; }
  @action clear() { this.query = ""; this.change(); }
  @action change(event) {
    event?.preventDefault();
    const value = this.query;
    const url = new URL(this.router.currentURL, window.location.origin);
    url.searchParams.delete("page");
    if (value.trim()) url.searchParams.set("search", value.trim());
    else url.searchParams.delete("search");
    const directory = /overview|forums|categories/.test(this.router.currentRouteName);
    const path = this.router.currentRouteName.startsWith("discourse-post-event-upcoming-events") || directory ? (this.category?.url || "/latest") : url.pathname;
    DiscourseURL.routeTo(`${path}${url.search}`);
  }
  <template>
    {{#if this.visible}}
      <div class={{if @panel "svdex-panel-search" "svdex-discovery-search inline-form"}}>
        <form role="search" aria-label={{this.placeholder}} {{on "submit" this.change}} {{didUpdate this.syncSearch this.committedSearch}}>
          <DFilterInput @icons={{hash left="magnifying-glass"}} @value={{this.query}} @filterAction={{this.update}} @onClearInput={{this.clear}} placeholder={{this.placeholder}} aria-label={{this.placeholder}} />
        </form>
      </div>
    {{/if}}
  </template>
}
