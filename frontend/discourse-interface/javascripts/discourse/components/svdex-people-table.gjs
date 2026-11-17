import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import DUserInfo from "discourse/ui-kit/d-user-info";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

class NetWorthDetails extends Component {
  <template>
    <DModal @title="Estimated net worth" @closeModal={{@closeModal}}>
      <:body>
        <p><strong>{{@model.name}}: {{@model.estimate.value}}</strong></p>
        <p>As of {{@model.estimate.date}}</p>
        <p>{{@model.estimate.basis}}</p>
        <a href={{@model.estimate.source}} target="_blank" rel="noopener noreferrer">View source</a>
      </:body>
    </DModal>
  </template>
}
class PersonRow extends Component {
  @service modal;
  @service site;
  get person() { return this.args.item.user.svdex_person || {}; }
  get affiliations() {
    const organizations = this.person.organizations || [];
    return organizations.map(organization => ({ ...organization,
      role: organization.role || (organizations.length === 1 ? this.person.role : null),
    }));
  }
  get facts() {
    const currentRoles = this.site.mobileView
      ? (this.affiliations.length ? this.affiliations.flatMap(organization => [
          { label: "Organization", organization },
          { label: "Current title", value: organization.role },
        ]) : [{ label: "Current title", value: this.person.role }])
      : [{ label: "Current roles", organizations: this.affiliations, value: this.person.role }];
    return [
      ...currentRoles,
      { label: "Location", value: this.person.location },
      { label: "Est. net worth", estimate: this.person.net_worth },
    ];
  }
  @action showEstimate() {
    this.modal.show(NetWorthDetails, { model: { name: this.args.item.user.name, estimate: this.person.net_worth } });
  }
  <template>
    <div class="directory-table__row" role="row">
      <div class="directory-table__cell" role="rowheader">
        <DUserInfo @headingLevel={{3}} @user={{@item.user}} class="svdex-person-named" />
      </div>
      {{#each this.facts as |fact|}}
        <div class="directory-table__cell--user-field" role="cell">
          <span class="directory-table__label"><span>{{fact.label}}</span></span>
          <span class="directory-table__value--user-field">
            {{#if fact.organization}}
              <a class="svdex-person-organization" href={{fact.organization.url}}>{{fact.organization.name}}</a>
            {{else if fact.organizations}}
              {{#each fact.organizations as |organization|}}
                <span class="svdex-person-affiliation">
                  <a class="svdex-person-organization" href={{organization.url}}>{{organization.name}}</a>
                  {{#if organization.role}}<span class="svdex-person-role">{{organization.role}}</span>{{/if}}
                </span>
              {{/each}}
            {{else if fact.estimate}}
              <DButton class="btn-link svdex-person-estimate" @translatedLabel={{fact.estimate.value}} @translatedTitle="View estimate source and assumptions" @action={{this.showEstimate}} />
            {{else}}{{or fact.value "—"}}{{/if}}
          </span>
        </div>
      {{/each}}
    </div>
  </template>
}
export default class PeopleTable extends Component {
  columns = ["Current roles", "Location", "Est. net worth"];
  <template>
    <DResponsiveTable @ariaLabel="People" @className="svdex-people-table" @style="grid-template-columns: minmax(19em, 2fr) minmax(16em, 1.6fr) minmax(10em, 1fr) minmax(10em, 1fr);">
      <:header>
        <DTableHeaderToggle @automatic={{true}} @field="username" @labelKey="svdex.people.person" @order={{@order}} @asc={{@asc}} @onToggle={{@updateOrderAndAsc}} />
        {{#each this.columns as |column|}}
          <div class="directory-table__column-header" role="columnheader"><span class="header-contents">{{column}}</span></div>
        {{/each}}
      </:header>
      <:body>{{#each @items as |item|}}<PersonRow @item={{item}} />{{/each}}</:body>
    </DResponsiveTable>
  </template>
}
