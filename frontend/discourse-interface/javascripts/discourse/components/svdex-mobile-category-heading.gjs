import ProductStatusFilter from "./svdex-product-status-filter.gjs";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { isPresaleCategory } from "../lib/svdex-presales";

export default class MobileCategoryHeading extends Component {
  @service site;
  @service siteSettings;
  get label() {
    if (isPresaleCategory(this.args.outletArgs.category?.id, this.siteSettings)) return "Products";
    return this.args.outletArgs.category?.name || this.args.outletArgs.tag?.name;
  }
  <template>
    {{#if this.site.mobileView}}
      {{#if this.label}}<div class="svdex-mobile-heading-row"><h2 class="svdex-mobile-category-heading">{{this.label}}</h2><ProductStatusFilter @category={{@outletArgs.category}} @inline={{true}} /></div>{{/if}}
    {{/if}}
  </template>
}
