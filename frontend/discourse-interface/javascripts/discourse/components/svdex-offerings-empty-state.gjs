import { isOfferingCategory } from "../lib/svdex-offering-categories";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DEmptyState from "discourse/ui-kit/d-empty-state";

export default class OfferingsEmptyState extends Component {
  @service router;
  @service siteSettings;
  get visible() {
    const { category, model } = this.args.outletArgs;
    const query = this.router.currentRoute?.queryParams || {};
    return isOfferingCategory(category?.id, this.siteSettings) &&
      model?.list?.topics?.length === 0 && Boolean(query.svdex_company || query.svdex_valuation || query.tags || this.args.outletArgs.tag);
  }
  @action clearFilters() {
    const current = new URL(this.router.currentURL, window.location.origin);
    const params = current.searchParams;
    ["svdex_company", "svdex_valuation", "tags", "match_all_tags", "no_tags", "page"].forEach(key => params.delete(key));
    const sort = current.pathname.match(/\/l\/(latest|top|new|unread|unseen|hot)$/)?.[0] || "";
    DiscourseURL.routeTo(`${this.args.outletArgs.category.url}${sort}${params.size ? `?${params}` : ""}`);
  }
  <template>
    {{#if this.visible}}
      <DEmptyState
        @title="No offerings match these filters"
        @body="Try changing the company, sector or valuation filters."
        @ctaLabel="Clear filters"
        @ctaAction={{this.clearFilters}}
      />
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
