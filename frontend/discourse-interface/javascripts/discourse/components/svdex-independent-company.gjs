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
import CompanyProfileSummary from "./svdex-company-profile-summary.gjs";

class CompanyEditor extends Component {
  @tracked values;
  @tracked saving = false;
  constructor() {
    super(...arguments);
    const data = this.args.model.data;
    this.values = { ...data.profile, official_username: data.editor.official_username || "", facts: { ...data.editor.facts } };
  }
  fields = [{ key: "name", label: "Company name" }, { key: "summary", label: "Summary" }, { key: "official_username", label: "Official account username (optional)" }];
  facts = [{ key: "total_funding_usd", label: "Total funding (USD)", min: 0 }, { key: "last_valuation_usd", label: "Last valuation (USD)", min: 1 }];
  @action update(key, event) { this.values = { ...this.values, [key]: event.target.value }; }
  @action updateFact(key, event) { this.values = { ...this.values, facts: { ...this.values.facts, [key]: event.target.value } }; }
  @action async save() {
    this.saving = true;
    try {
      const data = await ajax(`/company-profiles/${encodeURIComponent(this.args.model.data.profile.slug)}.json`, { type: "PUT", contentType: "application/json", data: JSON.stringify({ profile: this.values }) });
      this.args.model.saved(data);
      this.args.closeModal();
    } catch (error) { popupAjaxError(error); }
    finally { this.saving = false; }
  }
  <template>
    <DModal @title="Edit company" @closeModal={{@closeModal}}>
      <:body>
        {{#each this.fields as |field|}}<div class="control-group"><label for="company-profile-{{field.key}}">{{field.label}}</label><input id="company-profile-{{field.key}}" value={{get this.values field.key}} maxlength={{if (eq field.key "summary") 180 120}} disabled={{this.saving}} {{on "input" (fn this.update field.key)}} /></div>{{/each}}
        {{#each this.facts as |field|}}<div class="control-group"><label for="company-profile-{{field.key}}">{{field.label}}</label><input id="company-profile-{{field.key}}" type="number" min={{field.min}} max="9007199254740991" step="1" value={{get this.values.facts field.key}} disabled={{this.saving}} {{on "input" (fn this.updateFact field.key)}} /></div>{{/each}}
      </:body>
      <:footer><DButton @translatedLabel="Save changes" @action={{this.save}} @disabled={{this.saving}} class="btn-primary" /><DButton @translatedLabel="Cancel" @action={{@closeModal}} /></:footer>
    </DModal>
  </template>
}
export default class IndependentCompany extends Component {
  @service modal;
  @tracked updated;
  get data() { return this.updated || this.args.model; }
  @action saved(data) { this.updated = data; }
  @action async refresh() { this.updated = await ajax(`/company-profiles/${encodeURIComponent(this.data.profile.slug)}.json`); }
  @action edit() { this.modal.show(CompanyEditor, { model: { data: this.data, saved: this.saved } }); }
  <template>
    <div class="user-main user-summary-page">
      <div class="svdex-independent-company-header">
        <div><h1>{{this.data.profile.name}}</h1><p>{{this.data.profile.summary}}</p></div>
        <div class="svdex-independent-company-actions">
          {{#if this.data.account}}<DButton @href={{this.data.account.activity_url}} @translatedLabel="Official account activity" />{{/if}}
          {{#if this.data.editor}}<DButton @action={{this.edit}} @icon="pencil" @translatedLabel="Edit company" />{{/if}}
        </div>
      </div>
      <div class="user-content"><CompanyProfileSummary @data={{this.data}} @user={{this.data.interest_account}} @independent={{true}} @onRefresh={{this.refresh}} /></div>
    </div>
  </template>
}
