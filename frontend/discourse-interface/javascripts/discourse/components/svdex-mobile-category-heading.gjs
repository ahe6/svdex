import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class MobileCategoryHeading extends Component {
  @service site;
  get label() { return this.args.outletArgs.category?.name || this.args.outletArgs.tag?.name; }
  <template>
    {{#if this.site.mobileView}}
      {{#if this.label}}<h2 class="svdex-mobile-category-heading">{{this.label}}</h2>{{/if}}
    {{/if}}
  </template>
}
