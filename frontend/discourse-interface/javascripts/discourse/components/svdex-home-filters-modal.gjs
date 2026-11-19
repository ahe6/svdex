import TagDrop from "discourse/select-kit/components/tag-drop";
import HomeTags from "./svdex-home-tags.gjs";
import DiscoverySearch from "./svdex-discovery-search.gjs";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { registerDestructor } from "@ember/destroyable";
import DModal from "discourse/ui-kit/d-modal";
import DButton from "discourse/ui-kit/d-button";
import { action } from "@ember/object";
import { hash } from "@ember/helper";
import BreadCrumbs from "discourse/components/bread-crumbs";
import DiscourseURL from "discourse/lib/url";
import ListingTagGroupFilters from "./svdex-tag-group-filters.gjs";
import { activeFilterCount } from "../lib/svdex-mobile-filters";
import { isProductCatalog, productFilterValue } from "../lib/svdex-products";
import ProductTypeFilter from "./svdex-product-type-filter.gjs";

// Use the same selectors as core breadcrumbs, inside the mobile filter panel.
export default class HomeFiltersModal extends Component {
  @service site;
  @service siteSettings;
  @service router;

  constructor() {
    super(...arguments);
    const close = () => this.args.closeModal();
    this.router.on("routeDidChange", close);
    registerDestructor(this, () => this.router.off("routeDidChange", close));
  }

  get categories() {
    return this.site.categoriesList.filter(category =>
      (this.siteSettings.allow_uncategorized_topics || category.id !== this.site.uncategorized_category_id)
    );
  }

  get active() {
    return activeFilterCount(this.router.currentRoute?.queryParams, this.args.model.tag, this.args.model.additionalTags) > 0 ||
      (this.productCatalog && productFilterValue(this.args.model.category?.id, this.router.currentURL, this.siteSettings) !== "all");
  }
  get productCatalog() { return isProductCatalog(this.args.model.category?.id, this.siteSettings); }

  @action clear() {
    const params = new URLSearchParams(this.router.currentURL.split("?")[1]);
    ["tags", "match_all_tags", "no_tags", "svdex_company", "svdex_valuation", "svdex_presales", "search", "page"].forEach(key => params.delete(key));
    const mode = /\/(top|latest|new|unread|unseen|hot)$/.exec(this.router.currentURL.split("?")[0])?.[1] || "latest";
    const products = this.site.categories.find(category => Number(category.id) === Number(this.siteSettings.svdex_products_category_id));
    const category = this.productCatalog ? products : this.args.model.category;
    const path = category ? `${category.url}/l/${mode}` : `/${mode}`;
    DiscourseURL.routeTo(`${path}${params.size ? `?${params}` : ""}`);
  }

  <template>
    <DModal @title="Filters" @closeModal={{@closeModal}} class={{if @model.isOffering "svdex-listing-filters-modal svdex-offerings-filters" "svdex-listing-filters-modal"}}>
      <:body>
        {{#unless @model.isOffering}}<DiscoverySearch @panel={{true}} @outletArgs={{@model}} />{{/unless}}
        {{#if this.productCatalog}}
          <ProductTypeFilter @model={{@model}} />
          <TagDrop @currentCategory={{@model.category}} @tag={{@model.tag}} />
        {{else if @model.isOffering}}
          <TagDrop @currentCategory={{@model.category}} @tag={{@model.tag}} />
        {{else if @model.homeFeed}}
          <HomeTags @outletArgs={{@model}} />
        {{else}}
          <BreadCrumbs class="svdex-mobile-native-filters" @categories={{this.categories}}
            @category={{@model.category}} @tag={{@model.tag}} @additionalTags={{@model.additionalTags}} />
        {{/if}}
        {{#if @model.isOffering}}
          <ul class="svdex-mobile-filter-fields">
            <ListingTagGroupFilters @panel={{true}} @outletArgs={{hash currentCategory=@model.category tag=@model.tag additionalTags=@model.additionalTags}} />
          </ul>
        {{/if}}
      </:body>
      <:footer>
        <DButton @translatedLabel="Done" @action={{@closeModal}} class="btn-primary" />
        {{#if this.active}}<DButton @translatedLabel="Clear filters" @action={{this.clear}} class="btn-default" />{{/if}}
      </:footer>
    </DModal>
  </template>
}
