import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { hash } from "@ember/helper";
import { fn } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import { PRODUCT_STAGES } from "../lib/svdex-products";

const SORTS = [
  { id: "0", name: "Most upvotes first" },
  { id: "1", name: "Fewest upvotes first" },
];

export default class ProductDirectoryFilters extends Component {
  @service router;
  @service("svdex-product-directory") directory;
  stages = PRODUCT_STAGES;
  sorts = SORTS;

  get query() { return this.router.currentRoute?.queryParams || {}; }
  get category() { return Number(this.query.svdex_product_category) || null; }
  get stage() { return this.query.svdex_product_stage || null; }
  get sort() { return this.query.svdex_product_asc === "1" ? "1" : "0"; }

  @action change(key, value) {
    this.router.transitionTo({ queryParams: { [key]: value && value !== "0" ? String(value) : null } });
  }

  <template>
    <div class="svdex-company-filter-fields">
      <ComboBox @content={{this.directory.categories}} @value={{this.category}} @onChange={{fn this.change "svdex_product_category"}}
        @options={{hash translatedNone="Category" filterable=true clearable=true}} aria-label="Filter by category" />
      {{#unless @presalesOnly}}
        <ComboBox @content={{this.stages}} @value={{this.stage}} @onChange={{fn this.change "svdex_product_stage"}}
          @options={{hash translatedNone="Stage" clearable=true}} aria-label="Filter by stage" />
      {{/unless}}
      <ComboBox @content={{this.sorts}} @value={{this.sort}} @onChange={{fn this.change "svdex_product_asc"}}
        aria-label="Sort by upvotes" />
    </div>
  </template>
}
