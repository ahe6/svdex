import InterestButton from "./svdex-interest.gjs";
import { modifier } from "ember-modifier";
import { service } from "@ember/service";
import Component from "@glimmer/component";
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
  get company() { return this.args.item.company || this.args.item.user?.svdex_company || {}; }
  get facts() { return directoryFacts(this.company, this.args.kind).map(fact => ({...fact,
    missingInterest: fact.value === "—",
    interestSide: fact.key === "buy_interest" ? "buy" : fact.key === "sell_interest" ? "sell" : null,
    interestTitle: `Indicate ${fact.key === "buy_interest" ? "buy" : "sell"} interest in ${this.organizationName}`,
  })); }
  get organizationName() { return this.args.item.profile?.name || this.args.item.user.name || this.args.item.user.username; }
  get profileUrl() { return this.args.item.profile?.url || `/u/${encodeURIComponent(this.args.item.user.username)}/summary`; }
  <template>
    <div class="directory-table__row" role="row">
      <div class="directory-table__cell" role="rowheader" {{companyProfileLinks this.profileUrl}}>{{#if @item.profile}}<div class="user-info svdex-company-named"><div class="user-detail"><div class="name-line"><span class="name-wrapper"><a class="name" href={{this.profileUrl}}>{{@item.profile.name}}</a></span></div><span class="svdex-company-summary">{{@item.profile.summary}}</span></div></div>{{else}}<DUserInfo @headingLevel={{3}} @user={{@item.user}} class={{if @item.user.name "svdex-company-named"}} />{{/if}}</div>
      {{#each this.facts as |fact|}}
        <div class="directory-table__cell--user-field" role="cell">
          <span class="directory-table__label"><span>{{fact.label}}</span></span>
          <span class="directory-table__value--user-field">
            {{#if fact.interestSide}}{{#if this.siteSettings.svdex_interest_enabled}}
              <InterestButton @interestEndpoint={{@item.interestEndpoint}} @organizationId={{or @item.profile.id @item.user.id}} @organizationName={{this.organizationName}} @side={{fact.interestSide}} @label={{fact.value}} @title={{fact.interestTitle}} @buttonClass={{if fact.missingInterest "btn-link svdex-directory-interest svdex-directory-interest--unknown" "btn-link svdex-directory-interest"}} @onChange={{@refreshInterest}} />
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
  // The identity/summary occupies the native username slot plus one statistic.
  // Explicit tracks avoid mounting a hidden Users table and measuring its labels.
  get gridStyle() {
    return `grid-template-columns: minmax(24em, 4fr) repeat(${this.columns.length}, minmax(min-content, 1fr));`;
  }
  get columns() {
    const canSortInterest = this.siteSettings.svdex_interest_enabled && (this.siteSettings.svdex_interest_public_totals || (this.currentUser?.staff && this.siteSettings.svdex_interest_staff_preview));
    return directoryColumns(this.args.controller.kind).map(column => ({ ...column, sort: canSortInterest ? column.sort : null, filter: column.sort && !canSortInterest ? null : column.filter }));
  }
  <template>
    <div class="svdex-companies-grid">
      <DResponsiveTable @ariaLabel={{if @controller.isFund "Funds" "Companies"}} @className="svdex-companies-table" @style={{this.gridStyle}}>
        <:header>
          <DTableHeaderToggle @automatic={{true}} @field="username" @labelKey={{@identityKey}} @order={{@order}} @asc={{@asc}} @onToggle={{@updateOrderAndAsc}} />
          {{#each this.columns as |column|}}
            {{#if column.filter}}<CompanyColumnMenu @controller={{@controller}} @label={{column.label}} @field={{column.filter}} />
            {{else}}<div class="directory-table__column-header" role="columnheader"><span class="header-contents">{{column.label}}</span></div>{{/if}}
          {{/each}}
        </:header>
        <:body>{{#each @items as |item|}}<CompanyRow @item={{item}} @kind={{@controller.kind}} @refreshInterest={{@controller.refreshInterest}} />{{/each}}</:body>
      </DResponsiveTable>
    </div>
  </template>
}
