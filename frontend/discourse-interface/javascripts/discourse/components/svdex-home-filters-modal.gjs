import ProductDirectoryFilters from "./svdex-product-directory-filters.gjs";
import { or } from "truth-helpers";
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
import { isProductCatalog } from "../lib/svdex-products";
import { isPresaleCategory } from "../lib/svdex-presales";

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
    const query = this.router.currentRoute?.queryParams;
    return activeFilterCount(query, this.args.model.tag, this.args.model.additionalTags) > 0 ||
      Boolean(query?.svdex_presales || query?.svdex_product_category || query?.svdex_product_stage || query?.svdex_product_asc);
  }
  get productCatalog() { return isProductCatalog(this.args.model.category?.id, this.siteSettings); }
  get productDirectory() { return this.productCatalog && this.router.currentRoute?.queryParams.svdex_view === "directory"; }
  get presalesOnly() { return isPresaleCategory(this.args.model.category?.id, this.siteSettings); }

  @action clear() {
    const params = new URLSearchParams(this.router.currentURL.split("?")[1]);
    ["tags", "match_all_tags", "no_tags", "svdex_company", "svdex_valuation", "svdex_presales", "svdex_product_category", "svdex_product_stage", "svdex_product_asc", "search", "page"].forEach(key => params.delete(key));
    const mode = /\/(top|latest|new|unread|unseen|hot)$/.exec(this.router.currentURL.split("?")[0])?.[1] || "latest";
    const category = this.args.model.category;
    const noSubcategories = this.args.model.noSubcategories || /\/none(?:\/|$)/.test(this.router.currentURL.split("?")[0]);
    const path = category ? `${category.url}${noSubcategories ? "/none" : ""}/l/${mode}` : `/${mode}`;
    DiscourseURL.routeTo(`${path}${params.size ? `?${params}` : ""}`);
  }

  <template>
    <DModal @title="Filters" @closeModal={{@closeModal}} class={{if @model.isOffering "svdex-listing-filters-modal svdex-offerings-filters" "svdex-listing-filters-modal"}}>
      <:body>
        {{#unless @model.isOffering}}<DiscoverySearch @panel={{true}} @outletArgs={{@model}} />{{/unless}}
        {{#if this.productDirectory}}
          <ProductDirectoryFilters @presalesOnly={{this.presalesOnly}} />
        {{else if (or this.productCatalog @model.isOffering)}}
          <TagDrop @currentCategory={{@model.category}} @tag={{@model.tag}} @noSubcategories={{@model.noSubcategories}} />
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
