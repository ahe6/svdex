import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { hash, fn } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import CompanySort from "./svdex-company-sort.gjs";
import FilterTrigger from "./svdex-filter-trigger.gjs";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

export default class PeopleFilters extends Component {
  @service site;
  @tracked open = false;
  sorts = [
    { id: "username:asc", name: "Name: A–Z", field: "username", asc: true },
    { id: "username:desc", name: "Name: Z–A", field: "username", asc: null },
    { id: "svdex_age:desc", name: "Age: oldest first", field: "svdex_age", asc: null },
    { id: "svdex_age:asc", name: "Age: youngest first", field: "svdex_age", asc: true },
    { id: "svdex_net_worth:desc", name: "All-Time Money: highest first", field: "svdex_net_worth", asc: null },
    { id: "svdex_net_worth:asc", name: "All-Time Money: lowest first", field: "svdex_net_worth", asc: true },
  ];
  get organization() { return Number(this.args.controller.svdex_organization) || null; }
  @action show(event) { this.trigger = event?.currentTarget; this.open = true; }
  @action close() { this.open = false; this.trigger?.focus(); }
  <template>
    <span class="svdex-people-filter-control">
      <FilterTrigger @compact={{this.site.mobileView}} @active={{@controller.hasPeopleFilters}} @action={{this.show}} />
    </span>
    {{#if this.open}}
      <DModal @title="Filters" @closeModal={{this.close}} class="svdex-company-filters-modal">
        <:body>
          <CompanySort @options={{this.sorts}} @defaultOrder="username" @order={{@controller.order}} @asc={{@controller.asc}} @onChange={{@controller.updateOrderAndAsc}} />
          <div class="svdex-company-filter-fields">
            <label for="svdex-people-organization">Current organization</label>
            <ComboBox @id="svdex-people-organization" @content={{@controller.organizations}} @value={{this.organization}}
              @onChange={{fn @controller.changeFilter "svdex_organization"}} @options={{hash none="svdex.company.any" clearable=true}} />
            <label for="svdex-people-location">Location</label>
            <ComboBox @id="svdex-people-location" @content={{@controller.locations}} @value={{@controller.svdex_location}}
              @onChange={{fn @controller.changeFilter "svdex_location"}} @options={{hash none="svdex.company.all_locations" clearable=true}} />
          </div>
        </:body>
        <:footer>
          <DButton @translatedLabel="Done" @action={{this.close}} class="btn-primary" />
          <DButton @translatedLabel="Clear filters" @action={{@controller.clearFilters}} />
        </:footer>
      </DModal>
    {{/if}}
  </template>
}
