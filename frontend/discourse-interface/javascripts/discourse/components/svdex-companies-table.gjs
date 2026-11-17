import InterestButton from "./svdex-interest.gjs";
import { modifier } from "ember-modifier";
import { service } from "@ember/service";
import Component from "@glimmer/component";
import NativeDirectoryTable from "discourse/components/directory-table";
import companyGrid from "../modifiers/svdex-company-grid";
import CompanyColumnMenu from "./svdex-company-column-menu.gjs";
import OrganizationReferences from "./svdex-organization-references.gjs";
import { directoryColumns, directoryFacts } from "../lib/svdex-directory-columns";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import DUserInfo from "discourse/ui-kit/d-user-info";

// The native user-info markup supplies the directory typography. Organization
// identities open their summary directly; ordinary user links retain cards.
const companyProfileLinks = modifier((element, [url]) => {
  element.querySelectorAll("a[data-user-card]").forEach(link => {
    link.removeAttribute("data-user-card");
    link.href = url;
  });
});
class CompanyRow extends Component {
  @service siteSettings;
  get company() { return this.args.item.user.svdex_company || {}; }
  get facts() { return directoryFacts(this.company, this.args.kind).map(fact => ({...fact,
    missingInterest: fact.value === "—",
    interestSide: fact.key === "buy_interest" ? "buy" : fact.key === "sell_interest" ? "sell" : null,
    interestTitle: `Indicate ${fact.key === "buy_interest" ? "buy" : "sell"} interest in ${this.args.item.user.name || this.args.item.user.username}`,
  })); }
  get organizationName() { return this.args.item.user.name || this.args.item.user.username; }
  get profileUrl() { return `/u/${encodeURIComponent(this.args.item.user.username)}/summary`; }
  <template>
    <div class="directory-table__row" role="row">
      <div class="directory-table__cell" role="rowheader" {{companyProfileLinks this.profileUrl}}><DUserInfo @headingLevel={{3}} @user={{@item.user}} class={{if @item.user.name "svdex-company-named"}} /></div>
      {{#each this.facts as |fact|}}
        <div class="directory-table__cell--user-field" role="cell">
          <span class="directory-table__label"><span>{{fact.label}}</span></span>
          <span class="directory-table__value--user-field">
            {{#if fact.interestSide}}{{#if this.siteSettings.svdex_interest_enabled}}
              <InterestButton @organizationId={{@item.user.id}} @organizationName={{this.organizationName}} @side={{fact.interestSide}} @label={{fact.value}} @title={{fact.interestTitle}} @buttonClass={{if fact.missingInterest "btn-link svdex-directory-interest svdex-directory-interest--unknown" "btn-link svdex-directory-interest"}} @onChange={{@refreshInterest}} />
              {{else}}{{fact.value}}{{/if}}
            {{else if fact.people}}<OrganizationReferences @entries={{this.company.key_people}} @showRoles={{false}} @limit={{2}} @profileUrl={{this.profileUrl}} />
            {{else if fact.url}}<a href={{fact.url}}>{{fact.value}}</a>{{else}}{{fact.value}}{{/if}}
          </span>
        </div>
      {{/each}}
    </div>
  </template>
}
export default class CompaniesTable extends Component {
  @service currentUser;
  @service siteSettings;
  get referenceOrder() { return this.args.referenceColumns?.[0]?.name || "likes_received"; }
  get columns() {
    const canSortInterest = this.siteSettings.svdex_interest_enabled && (this.siteSettings.svdex_interest_public_totals || (this.currentUser?.staff && this.siteSettings.svdex_interest_staff_preview));
    return directoryColumns(this.args.controller.kind).map(column => ({ ...column, sort: canSortInterest ? column.sort : null, filter: column.sort && !canSortInterest ? null : column.filter }));
  }
  <template>
    <div class="svdex-companies-grid" data-financial-columns={{this.columns.length}} {{companyGrid}}>
      <DResponsiveTable @ariaLabel={{if @controller.isFund "Funds" "Companies"}} @className="svdex-companies-table" @style="grid-template-columns: minmax(15em, 3fr) repeat(7, minmax(min-content, 1fr));">
        <:header>
          <DTableHeaderToggle @automatic={{true}} @field="username" @labelKey={{@identityKey}} @order={{@order}} @asc={{@asc}} @onToggle={{@updateOrderAndAsc}} />
          {{#each this.columns as |column|}}
            {{#if column.filter}}<CompanyColumnMenu @controller={{@controller}} @label={{column.label}} @field={{column.filter}} />
            {{else}}<div class="directory-table__column-header" role="columnheader"><span class="header-contents">{{column.label}}</span></div>{{/if}}
          {{/each}}
        </:header>
        <:body>{{#each @items as |item|}}<CompanyRow @item={{item}} @kind={{@controller.kind}} @refreshInterest={{@controller.refreshInterest}} />{{/each}}</:body>
      </DResponsiveTable>
      <div class="svdex-company-grid-reference" aria-hidden="true" inert><NativeDirectoryTable @columns={{@referenceColumns}} @order={{this.referenceOrder}} /></div>
    </div>
  </template>
}
