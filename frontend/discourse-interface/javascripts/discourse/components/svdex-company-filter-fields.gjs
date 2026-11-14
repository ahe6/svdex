import { service } from "@ember/service";
import Component from "@glimmer/component";
import { hash, fn } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";

import { MONEY_RANGES, OPEN_OFFERING_OPTIONS } from "../lib/svdex-company-filters";

export default class CompanyFilterFields extends Component {
  @service siteSettings;
  @service currentUser;
  get interestVisible() { return this.siteSettings.svdex_interest_enabled && (this.siteSettings.svdex_interest_public_totals || (this.currentUser?.staff && this.siteSettings.svdex_interest_staff_preview)); }
  get ranges() { return MONEY_RANGES; }
  get openOptions() { return OPEN_OFFERING_OPTIONS; }
  get sector() { return !this.args.controller.isFund && (!this.args.field || this.args.field === "svdex_sector"); }
  get funding() { return !this.args.controller.isFund && (!this.args.field || this.args.field === "svdex_funding"); }
  get valuation() { return !this.args.controller.isFund && (!this.args.field || this.args.field === "svdex_valuation"); }
  get entityTypes() { return [{id:"company", name:"Company"}, {id:"spv", name:"SPV"}]; }
  <template>
    <div class="svdex-company-filter-fields">
      {{#if this.sector}}
        <label for="svdex-company-filter-sector">Sector</label>
        <ComboBox @id="svdex-company-filter-sector" @content={{@controller.sectors}} @value={{@values.svdex_sector}} @onChange={{fn @onChange "svdex_sector"}} @options={{hash none="svdex.company.all_sectors" clearable=true}} />
      {{/if}}
      {{#if this.funding}}
        <label for="svdex-company-filter-funding">Total funding</label>
        <ComboBox @id="svdex-company-filter-funding" @content={{this.ranges}} @value={{@values.svdex_funding}} @onChange={{fn @onChange "svdex_funding"}} @options={{hash none="svdex.company.all_values" clearable=true}} />
      {{/if}}
      {{#if this.valuation}}
        <label for="svdex-company-filter-valuation">Last valuation</label>
        <ComboBox @id="svdex-company-filter-valuation" @content={{this.ranges}} @value={{@values.svdex_valuation}} @onChange={{fn @onChange "svdex_valuation"}} @options={{hash none="svdex.company.all_values" clearable=true}} />
      {{/if}}
      {{#unless @field}}
        {{#if this.interestVisible}}<label for="svdex-company-filter-buy-interest">Buy interest</label>
        <ComboBox @id="svdex-company-filter-buy-interest" @content={{this.ranges}} @value={{@values.svdex_buy_interest}} @onChange={{fn @onChange "svdex_buy_interest"}} @options={{hash none="svdex.company.all_values" clearable=true}} />
        <label for="svdex-company-filter-sell-interest">Sell interest</label>
        <ComboBox @id="svdex-company-filter-sell-interest" @content={{this.ranges}} @value={{@values.svdex_sell_interest}} @onChange={{fn @onChange "svdex_sell_interest"}} @options={{hash none="svdex.company.all_values" clearable=true}} />{{/if}}
        {{#if @controller.isFund}}
          <label for="svdex-company-filter-aum">AUM</label>
          <ComboBox @id="svdex-company-filter-aum" @content={{this.ranges}} @value={{@values.svdex_aum}} @onChange={{fn @onChange "svdex_aum"}} @options={{hash none="svdex.company.all_values" clearable=true}} />
        {{else}}
          <label for="svdex-company-filter-type">Entity type</label>
          <ComboBox @id="svdex-company-filter-type" @content={{this.entityTypes}} @value={{@values.svdex_type}} @onChange={{fn @onChange "svdex_type"}} @options={{hash none="svdex.company.any" clearable=true}} />
        {{/if}}
        {{#unless @controller.isFund}}<label for="svdex-company-filter-stage">Stage</label>
        <ComboBox @id="svdex-company-filter-stage" @content={{@controller.stages}} @value={{@values.svdex_stage}} @onChange={{fn @onChange "svdex_stage"}} @options={{hash none="svdex.company.all_stages" clearable=true}} />{{/unless}}
        <label for="svdex-company-filter-location">Location</label>
        <ComboBox @id="svdex-company-filter-location" @content={{@controller.locations}} @value={{@values.svdex_location}} @onChange={{fn @onChange "svdex_location"}} @options={{hash none="svdex.company.all_locations" clearable=true}} />
        <label for="svdex-company-filter-open">Open offerings</label>
        <ComboBox @id="svdex-company-filter-open" @content={{this.openOptions}} @value={{@values.svdex_open}} @onChange={{fn @onChange "svdex_open"}} @options={{hash none="svdex.company.any" clearable=true}} />
      {{/unless}}
    </div>
  </template>
}
