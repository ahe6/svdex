import Component from "@glimmer/component";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { companyFilterOptions } from "../lib/svdex-company-filters";

export default class CompanyColumnMenu extends Component {
  get sortField() { return this.args.sortField ?? this.companySortField; }
  get companySortField() { return this.args.field === "svdex_funding" ? "svdex_total_funding" : this.args.field === "svdex_valuation" ? "svdex_last_valuation" : ["svdex_aum", "svdex_buy_interest", "svdex_sell_interest"].includes(this.args.field) ? this.args.field : null; }
  get icon() { return this.sortField && this.args.controller.order === this.sortField && this.args.controller.asc ? "angle-up" : "angle-down"; }
  get hasFilters() { return Boolean(this.args.filter || this.args.field); }
  get title() {
    const actionName = this.hasFilters ? (this.sortField ? "Filter and sort" : "Filter") : "Sort";
    return `${actionName} ${this.args.label}`;
  }
  get value() {
    return this.args.filter ? this.args.filter.value : this.args.controller[this.args.field];
  }
  get active() { return Boolean(this.value); }
  get options() {
    if (!this.hasFilters) return [];
    const { reset, options } = this.args.filter || companyFilterOptions(this.args.controller, this.args.field);
    const current = this.value;
    return [{ id: null, name: reset }, ...options].map(option => ({ ...option, selected: String(option.id ?? "") === String(current ?? "") }));
  }
  get sortOptions() {
    const c = this.args.controller;
    return [
      { name: this.args.highestLabel ?? "Highest first", asc: null, selected: c.order === this.sortField && !c.asc },
      { name: this.args.lowestLabel ?? "Lowest first", asc: true, selected: c.order === this.sortField && Boolean(c.asc) },
    ];
  }
  @action registerMenu(api) { this.menu = api; }
  @action choose(value) {
    this.menu?.close();
    if (this.args.filter) this.args.filter.onChoose(value);
    else this.args.controller.changeCompanyFilter(this.args.field, value);
  }
  @action sort(asc) { this.args.controller.updateOrderAndAsc(this.sortField, asc); this.menu?.close(); }
  <template>
    <div class="directory-table__column-header" role="columnheader">
      <DMenu class="btn-flat header-contents svdex-company-column-trigger {{if this.active '--filtered'}}" @title={{this.title}} @onRegisterApi={{this.registerMenu}}>
        <:trigger><span class="text">{{@label}} {{dIcon this.icon}}</span></:trigger>
        <:content>
          <DDropdownMenu class="svdex-company-column-options" role="menu" aria-label={{@label}} as |dropdown|>
            {{#if this.sortField}}
              {{#each this.sortOptions as |option|}}
                <dropdown.item><DButton @action={{fn this.sort option.asc}} class={{if option.selected "-selected"}} role="menuitemradio" aria-checked={{if option.selected "true" "false"}}><span class="svdex-company-choice-mark">{{#if option.selected}}{{dIcon "check"}}{{/if}}</span><span>{{option.name}}</span></DButton></dropdown.item>
              {{/each}}
              {{#if this.hasFilters}}<dropdown.divider />{{/if}}
            {{/if}}
            {{#each this.options as |option|}}
              <dropdown.item><DButton @action={{fn this.choose option.id}} class={{if option.selected "-selected"}} role="menuitemradio" aria-checked={{if option.selected "true" "false"}}><span class="svdex-company-choice-mark">{{#if option.selected}}{{dIcon "check"}}{{/if}}</span><span>{{option.name}}</span></DButton></dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>
  </template>
}
