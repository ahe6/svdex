import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import DiscourseURL from "discourse/lib/url";
import { isProductCategory } from "../lib/svdex-products";

export default class PresalesChip extends Component {
  @service router;
  @service siteSettings;
  get visible() { return isProductCategory(this.args.outletArgs.category?.id, this.siteSettings); }
  get checked() { return String(this.router.currentRoute?.queryParams?.svdex_presales) === "1"; }
  @action toggle(event) {
    const url = new URL(this.router.currentURL, window.location.origin);
    url.searchParams.delete("page");
    if (event.target.checked) url.searchParams.set("svdex_presales", "1");
    else url.searchParams.delete("svdex_presales");
    DiscourseURL.routeTo(`${url.pathname}${url.search}`);
  }
  <template>{{#if this.visible}}<label class="svdex-presales-chip"><input type="checkbox" checked={{this.checked}} {{on "change" this.toggle}} />Pre-sales only</label>{{/if}}</template>
}
