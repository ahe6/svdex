import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import CompanyFiltersModal from "./svdex-company-filters-modal.gjs";
import CompanySearchModal from "./svdex-company-search-modal.gjs";

export default class CompanyMobileControls extends Component {
  @service modal;
  @tracked filtersOpen = false;
  @action filters(event) { this.filterTrigger = event?.currentTarget; this.filtersOpen = true; }
  @action closeFilters() { this.filtersOpen = false; this.filterTrigger?.focus(); }
  @action search() { this.modal.show(CompanySearchModal, { model: this.args.controller }); }
  get filterTitle() { return this.args.controller.hasCompanyFilters ? "Filters (active)" : "Filters"; }
  <template>
      <span class="svdex-company-mobile-controls">
        <DButton @icon="magnifying-glass" @translatedTitle={{@controller.searchTitle}} @translatedAriaLabel={{@controller.searchTitle}} @action={{this.search}} class={{if @controller.name "btn-primary svdex-company-search-trigger" "btn-default svdex-company-search-trigger"}} />
        <DButton @icon="angle-right" @translatedLabel="Filter" @translatedTitle={{this.filterTitle}} @translatedAriaLabel={{this.filterTitle}} @action={{this.filters}} class={{if @controller.hasCompanyFilters "btn-primary svdex-filter-trigger" "btn-default svdex-filter-trigger"}} />
      </span>
      {{#if this.filtersOpen}}
        <CompanyFiltersModal @model={{@controller}} @closeModal={{this.closeFilters}} />
      {{/if}}
  </template>
}
