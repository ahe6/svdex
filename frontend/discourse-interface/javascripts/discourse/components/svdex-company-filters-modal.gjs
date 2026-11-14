import Component from "@glimmer/component";
import { action } from "@ember/object";
import DModal from "discourse/ui-kit/d-modal";
import DButton from "discourse/ui-kit/d-button";
import CompanyFilterFields from "./svdex-company-filter-fields.gjs";
import CompanySort from "./svdex-company-sort.gjs";
import { COMPANY_FILTER_KEYS } from "../lib/svdex-company-filters";

export default class CompanyFiltersModal extends Component {
  get values() {
    return { ...Object.fromEntries(COMPANY_FILTER_KEYS.map(key => [key, this.args.model[key]])), svdex_sector: Number(this.args.model.svdex_sector) || null };
  }
  @action change(key, value) { this.args.model.changeCompanyFilter(key, value); }
  @action clear() { this.args.model.clearCompanyFilters(); }
  <template>
    <DModal @title="Filters" @closeModal={{@closeModal}} class="svdex-company-filters-modal">
      <:body>
        <CompanySort @kind={{@model.kind}} @order={{@model.order}} @asc={{@model.asc}} @onChange={{@model.updateOrderAndAsc}} />
        <CompanyFilterFields @controller={{@model}} @values={{this.values}} @onChange={{this.change}} />
      </:body>
      <:footer>
        <DButton @translatedLabel="Done" @action={{@closeModal}} class="btn-primary" />
        <DButton @translatedLabel="Clear filters" @action={{this.clear}} />
      </:footer>
    </DModal>
  </template>
}
