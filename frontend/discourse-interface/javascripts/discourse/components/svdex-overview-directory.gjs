import Component from "@glimmer/component";
import { service } from "@ember/service";
import CategoriesOnly from "discourse/components/categories-only";
import OverviewTags from "./svdex-overview-tags.gjs";

// Both discovery scopes use the same native directory layout. Their controllers
// continue to supply distinct, permission-aware category sets.
export default class OverviewDirectory extends Component {
  @service site;
  <template>
    <div class="contents">
      {{#if this.site.mobileView}}
        <CategoriesOnly @categories={{@categories}} />
        <OverviewTags />
      {{else}}
        <div class="categories-and-latest svdex-overview-directories">
          <div class="column categories"><CategoriesOnly @categories={{@categories}} /></div>
          <div class="column"><OverviewTags /></div>
        </div>
      {{/if}}
    </div>
  </template>
}
