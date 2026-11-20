import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import CompanyColumnMenu from "./svdex-company-column-menu.gjs";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import DUserInfo from "discourse/ui-kit/d-user-info";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import ProfileIdentity from "./svdex-profile-identity.gjs";

const moneyLabel = "All-Time Money";

class NetWorthDetails extends Component {
  <template>
    <DModal @title={{moneyLabel}} @closeModal={{@closeModal}}>
      <:body>
        <p><strong>{{@model.name}}: {{@model.estimate.value}}</strong></p>
        <p>As of {{@model.estimate.date}}</p>
        <a href={{@model.estimate.source}} target="_blank" rel="noopener noreferrer">View source</a>
      </:body>
    </DModal>
  </template>
}
class PersonRow extends Component {
  @service modal;
  get person() { return this.args.item.person || this.args.item.user?.svdex_person || {}; }
  get facts() {
    const organizations = this.person.organizations || [];
    return [
      { label: "Current roles", roles: organizations.filter(organization => organization.role), value: this.person.role },
      { label: "Affiliations", organizations },
      { label: "Location", value: this.person.location },
      { label: "Age", age: this.person.age },
      { label: moneyLabel, estimate: this.person.net_worth },
    ];
  }
  @action showEstimate() {
    this.modal.show(NetWorthDetails, { model: { name: this.args.item.profile?.name || this.args.item.user.name, estimate: this.person.net_worth } });
  }
  <template>
    <div class="directory-table__row" role="row">
      <div class="directory-table__cell" role="rowheader">
        {{#if @item.profile}}<ProfileIdentity @profile={{@item.profile}} />{{else}}<DUserInfo @headingLevel={{3}} @user={{@item.user}} class="svdex-person-named" />{{/if}}
      </div>
      {{#each this.facts as |fact|}}
        <div class="directory-table__cell--user-field" role="cell">
          <span class="directory-table__label"><span>{{fact.label}}</span></span>
          <span class="directory-table__value--user-field">
            {{#if fact.roles.length}}
              {{#each fact.roles as |organization|}}
                <span class="svdex-person-role" title={{organization.name}}>{{organization.role}}</span>
              {{/each}}
            {{else if fact.organizations.length}}
              {{#each fact.organizations as |organization|}}
                <a class="svdex-person-organization" href={{organization.url}}>{{organization.name}}</a>
              {{/each}}
            {{else if fact.estimate}}
              <DButton class="btn-link svdex-person-estimate" @translatedLabel={{fact.estimate.value}} @translatedTitle="View estimate source and date" @action={{this.showEstimate}} />
            {{else if fact.age}}
              <a href={{fact.age.source}} title="View birth year source" target="_blank" rel="noopener noreferrer">{{fact.age.value}}</a>
            {{else}}{{or fact.value "—"}}{{/if}}
          </span>
        </div>
      {{/each}}
    </div>
  </template>
}
export default class PeopleTable extends Component {
  columns = ["Current roles", "Current affiliations", "Location"];
  <template>
    <DResponsiveTable
      @ariaLabel="People"
      @className="svdex-people-table"
      @style="grid-template-columns: minmax(12em, 1.9fr) minmax(7em, .9fr) minmax(10em, 1.6fr) minmax(7em, 1.2fr) minmax(3.5em, .6fr) minmax(7.5em, 1.05fr);"
    >
      <:header>
        <DTableHeaderToggle @automatic={{true}} @field="username" @labelKey="svdex.people.person" @order={{@controller.order}} @asc={{@controller.asc}} @onToggle={{@controller.updateOrderAndAsc}} />
        {{#each this.columns as |column|}}
          <div class="directory-table__column-header" role="columnheader"><span class="header-contents">{{column}}</span></div>
        {{/each}}
        <CompanyColumnMenu @controller={{@controller}} @sortField="svdex_age" @label="Age" @highestLabel="Oldest first" @lowestLabel="Youngest first" />
        <CompanyColumnMenu @controller={{@controller}} @sortField="svdex_net_worth" @label="All-Time Money" />
      </:header>
      <:body>{{#each @items as |item|}}<PersonRow @item={{item}} />{{/each}}</:body>
    </DResponsiveTable>
  </template>
}
