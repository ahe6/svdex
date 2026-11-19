import { eq } from "truth-helpers";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn, get } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import CompanyCorrection from "./svdex-company-correction.gjs";
import DiscourseURL from "discourse/lib/url";
import DiscoveryAdmin from "./svdex-discovery-admin.gjs";
import CompanyProfileSummary from "./svdex-company-profile-summary.gjs";
import PersonProfileSummary from "./svdex-person-profile-summary.gjs";

class CompanyEditor extends Component {
  @tracked values;
  @tracked saving = false;
  constructor() {
    super(...arguments);
    const data = this.args.model.data;
    this.values = { ...data.profile, official_username: data.editor.official_username || "", facts: { ...data.editor.facts } };
  }
  get kind() { return this.args.model.data.profile.kind; }
  get editLabel() { return this.kind === "people" ? "Edit person" : this.kind === "funds" ? "Edit fund" : "Edit company"; }
  get fields() { const fields = [{ key: "name", label: this.kind === "people" ? "Name" : this.kind === "funds" ? "Fund name" : "Company name" }, { key: "summary", label: this.kind === "people" ? "Background" : "Summary" }, { key: "official_username", label: "Official account username (optional)" }]; return this.args.model.data.profile.catalog_managed ? fields.slice(2) : fields; }
  get facts() {
    if (this.args.model.data.profile.catalog_managed) return [];
    if (this.kind === "people") return [{key:"role",label:"Current title"},{key:"focus",label:"Focus"},{key:"location",label:"Location"},{key:"net_worth",label:"Est. net worth"},{key:"net_worth_source",label:"Net worth source (public HTTPS URL)"},{key:"net_worth_date",label:"Estimate date",type:"date"},{key:"net_worth_basis",label:"Estimate basis"}];
    if (this.kind === "funds") return [{key:"aum_usd",label:"AUM (USD)",min:0,type:"number"},{key:"strategy_focus",label:"Strategy"},{key:"vintage_year",label:"Vintage year",type:"number",min:1800},{key:"fund_life",label:"Fund life"},{key:"headquarters_country",label:"Location"}];
    return [{ key: "total_funding_usd", label: "Total funding (USD)", min: 0, type:"number" }, { key: "last_valuation_usd", label: "Last valuation (USD)", min: 1, type:"number" }];
  }
  @action update(key, event) { this.values = { ...this.values, [key]: event.target.value }; }
  @action updateFact(key, event) { this.values = { ...this.values, facts: { ...this.values.facts, [key]: event.target.value } }; }
  @action async save() {
    this.saving = true;
    try {
      const data = await ajax(`${this.args.model.data.profile.api_path}.json`, { type: "PUT", contentType: "application/json", data: JSON.stringify({ profile: this.args.model.data.profile.catalog_managed ? { official_username: this.values.official_username } : this.values }) });
      this.args.model.saved(data);
      this.args.closeModal();
    } catch (error) { popupAjaxError(error); }
    finally { this.saving = false; }
  }
  <template>
    <DModal @title={{if @model.data.profile.catalog_managed "Manage account" this.editLabel}} @closeModal={{@closeModal}}>
      <:body>
        {{#each this.fields as |field|}}<div class="control-group"><label for="company-profile-{{field.key}}">{{field.label}}</label><input id="company-profile-{{field.key}}" value={{get this.values field.key}} maxlength={{if (eq field.key "summary") 180 120}} disabled={{this.saving}} {{on "input" (fn this.update field.key)}} /></div>{{/each}}
        {{#each this.facts as |field|}}<div class="control-group"><label for="company-profile-{{field.key}}">{{field.label}}</label><input id="company-profile-{{field.key}}" type={{or field.type "text"}} min={{field.min}} max={{if (eq field.type "number") "9007199254740991"}} step={{if (eq field.type "number") "1"}} value={{get this.values.facts field.key}} disabled={{this.saving}} {{on "input" (fn this.updateFact field.key)}} /></div>{{/each}}
      </:body>
      <:footer><DButton @translatedLabel="Save changes" @action={{this.save}} @disabled={{this.saving}} class="btn-primary" /><DButton @translatedLabel="Cancel" @action={{@closeModal}} /></:footer>
    </DModal>
  </template>
}
export default class IndependentCompany extends Component {
  @service modal;
  @service currentUser;
  @tracked updated;
  get data() { return this.updated || this.args.model; }
  @action saved(data) { this.updated = data; }
  @action async refresh() { this.updated = await ajax(`${this.data.profile.api_path}.json`); }
  get discoveryEndpoint() { return `${this.data.profile.api_path}/discovery.json`; }
  get editLabel() { return this.data.profile.kind === "people" ? "Edit person" : this.data.profile.kind === "funds" ? "Edit fund" : "Edit company"; }
  @action suggest() {
    if (!this.currentUser) return DiscourseURL.routeTo("/login");
    this.modal.show(CompanyCorrection, { model: this.data });
  }
  @action edit() { this.modal.show(CompanyEditor, { model: { data: this.data, saved: this.saved } }); }
  <template>
    <div class="user-main user-summary-page">
      <div class="svdex-independent-company-header">
        <div><h1>{{this.data.profile.name}}</h1><p>{{this.data.profile.summary}}</p></div>
        <div class="svdex-independent-company-actions">
          {{#if this.data.account}}<DButton @href={{this.data.account.activity_url}} @translatedLabel="Official account activity" />{{/if}}
          {{#if this.data.profile.catalog_managed}}<DButton @action={{this.suggest}} @icon="pencil" @translatedLabel="Suggest changes" />{{/if}}
          {{#if this.data.editor}}<DButton @action={{this.edit}} @translatedLabel={{if this.data.profile.catalog_managed "Manage account" this.editLabel}} />{{/if}}
        </div>
      </div>
      <div class="user-content">{{#if this.data.person}}<PersonProfileSummary @data={{this.data}} />{{else}}<CompanyProfileSummary @data={{this.data}} @independent={{true}} @onRefresh={{this.refresh}} />{{/if}}{{#if this.data.editor}}<details><summary>Manage discovery credit</summary><DiscoveryAdmin @endpoint={{this.discoveryEndpoint}} @onSave={{this.refresh}} /></details>{{/if}}</div>
    </div>
  </template>
}
