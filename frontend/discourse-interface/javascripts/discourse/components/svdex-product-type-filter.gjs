import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { hash } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import NavItem from "discourse/models/nav-item";
import { productFilterValue } from "../lib/svdex-products";

export default class ProductTypeFilter extends Component {
  @service site;
  @service siteSettings;
  @service router;
  options = [
    { id: "all", name: "All products" },
    { id: "products", name: "Products only" },
    { id: "presales", name: "Pre-sales only" },
  ];
  get value() { return productFilterValue(this.args.model.category?.id, this.router.currentURL, this.siteSettings); }
  @action change(value) {
    if (!["all", "products", "presales"].includes(value)) return;
    const id = value === "presales" ? this.siteSettings.svdex_presales_category_id : this.siteSettings.svdex_products_category_id;
    const category = this.site.categories.find(item => Number(item.id) === Number(id));
    if (!category) return;
    const url = new URL(this.router.currentURL, window.location.origin);
    const mode = /\/l\/top(?:\/|$)/.test(url.pathname) ? "top" : "latest";
    const path = NavItem.pathFor(mode, { category, tag: this.args.model.tag, noSubcategories: value === "products" });
    url.searchParams.delete("page");
    DiscourseURL.routeTo(`${path}${url.search}`);
  }
  <template>
    <label class="svdex-product-type-filter">
      <span>Type</span>
      <ComboBox @content={{this.options}} @value={{this.value}} @onChange={{this.change}}
        @options={{hash filterable=false clearable=false}} />
    </label>
  </template>
}
