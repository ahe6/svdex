import { isPresaleCategory } from "../lib/svdex-presales";
import { isProductCategory } from "../lib/svdex-products";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import SortableColumn from "discourse/components/topic-list/header/sortable-column";
import { isOfferingCategory } from "../lib/svdex-offering-categories";

export default class DiscoveryTopicHeader extends Component {
  @service siteSettings;
  get label() {
    if (isProductCategory(this.args.category?.id, this.siteSettings)) return "Product";
    if (isPresaleCategory(this.args.category?.id, this.siteSettings)) return "Pre-sale";
    return isOfferingCategory(this.args.category?.id, this.siteSettings) ? "Offering" : "Event";
  }
  <template>
    <SortableColumn
      @activeOrder={{@activeOrder}}
      @ascending={{@ascending}}
      @bulkSelectEnabled={{@bulkSelectEnabled}}
      @bulkSelectHelper={{@bulkSelectHelper}}
      @canBulkSelect={{@canBulkSelect}}
      @canDoBulkActions={{@canDoBulkActions}}
      @category={{@category}}
      @changeSort={{@changeSort}}
      @forceName={{this.label}}
      @name={{@name}}
      @order="default"
      @showBulkToggle={{@showBulkToggle}}
    />
  </template>
}
