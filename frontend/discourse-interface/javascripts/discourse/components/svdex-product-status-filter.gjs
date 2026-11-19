import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import { eq } from "truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DiscourseURL from "discourse/lib/url";
import { isProductCatalog, productFilterValue } from "../lib/svdex-products";

export default class ProductStatusFilter extends Component {
  @service router;
  @service site;
  @service siteSettings;
  options = [{ id: "all", name: "All" }, { id: "products", name: "Launched" }, { id: "presales", name: "Pre-sales" }];
  get category() { return this.args.category || this.args.outletArgs?.category; }
  get visible() { return isProductCatalog(this.category?.id, this.siteSettings) && (this.args.inline || !this.site.mobileView); }
  get value() { return productFilterValue(this.category?.id, this.router.currentURL, this.siteSettings); }
  @action change(value) {
    if (!["all", "products", "presales"].includes(value)) return;
    const url = new URL(this.router.currentURL, window.location.origin);
    url.searchParams.delete("page");
    url.searchParams.delete("svdex_presales");
    if (value !== "all") url.searchParams.set("svdex_presales", value === "presales" ? "1" : "0");
    const parent = this.site.categories.find(item => Number(item.id) === Number(this.siteSettings.svdex_products_category_id));
    if (!parent) return;
    const path = url.pathname.replace(this.category.url, parent.url).replace(/\/none(?=\/|$)/, "");
    DiscourseURL.routeTo(`${path}${url.search}`);
  }
  <template>{{#if this.visible}}<div class="svdex-product-status" role="group" aria-label="Product availability">{{#each this.options as |option|}}<DButton @translatedLabel={{option.name}} @action={{fn this.change option.id}} aria-pressed={{if (eq this.value option.id) "true" "false"}} class="btn-default {{if (eq this.value option.id) 'is-active'}}" />{{/each}}</div>{{/if}}</template>
}
