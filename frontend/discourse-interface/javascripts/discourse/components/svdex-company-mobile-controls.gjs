import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import FilterTrigger from "./svdex-filter-trigger.gjs";
import CompanyFiltersModal from "./svdex-company-filters-modal.gjs";
import CompanySearchModal from "./svdex-company-search-modal.gjs";

export default class CompanyMobileControls extends Component {
  @service modal;
  @tracked filtersOpen = false;
  @action filters(event) { this.filterTrigger = event?.currentTarget; this.filtersOpen = true; }
  @action closeFilters() { this.filtersOpen = false; this.filterTrigger?.focus(); }
  @action search() { this.modal.show(CompanySearchModal, { model: this.args.controller }); }
  <template>
      <span class="svdex-company-mobile-controls">
        <DButton @icon="magnifying-glass" @translatedTitle={{@controller.searchTitle}} @translatedAriaLabel={{@controller.searchTitle}} @action={{this.search}} class={{if @controller.name "btn-primary svdex-company-search-trigger" "btn-default svdex-company-search-trigger"}} />
        <FilterTrigger @active={{@controller.hasCompanyFilters}} @action={{this.filters}} />
      </span>
      {{#if this.filtersOpen}}
        <CompanyFiltersModal @model={{@controller}} @closeModal={{this.closeFilters}} />
      {{/if}}
  </template>
}
