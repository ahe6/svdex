import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { tracked } from "@glimmer/tracking";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DiscourseURL from "discourse/lib/url";
import { isOfferingCategory } from "../lib/svdex-offering-categories";

export default class DiscoverySearch extends Component {
  @service router;
  @service site;
  @service siteSettings;
  @tracked query = this.router.currentRoute?.queryParams?.search || "";
  get category() { return this.args.outletArgs.category; }
  get visible() {
    if (this.args.panel) return true;
    return !this.site.mobileView && !isOfferingCategory(this.category?.id, this.siteSettings) &&
      !/overview|forums|categories/.test(this.router.currentRouteName || "") &&
      (this.router.currentRouteName?.startsWith("discovery.") || (this.category && this.router.currentRouteName?.startsWith("tags.")) || this.router.currentRouteName?.startsWith("discourse-post-event-upcoming-events"));
  }
  get placeholder() { return Number(this.category?.id) === Number(this.siteSettings.svdex_events_category_id) ? "Search events" : "Search topics"; }
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
        <form role="search" aria-label={{this.placeholder}} {{on "submit" this.change}}>
          <DFilterInput @value={{this.query}} @filterAction={{this.update}} @onClearInput={{this.clear}} placeholder={{this.placeholder}} aria-label={{this.placeholder}} />
        </form>
      </div>
    {{/if}}
  </template>
}
