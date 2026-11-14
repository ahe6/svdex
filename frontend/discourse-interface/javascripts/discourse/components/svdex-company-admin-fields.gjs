import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn, get, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import AdminReferences from "./svdex-admin-references.gjs";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";

export default class CompanyAdminFields extends Component {
  @tracked data;
  @tracked values = {};
  @tracked saving = false;
  @tracked saved = false;
  @tracked failed = false;

  get visible() { return this.args.outletArgs.model?.svdex_company_account; }
  get endpoint() { return `/listings/company-details/${this.args.outletArgs.model.id}.json`; }
  get isFund() { return this.data?.kind === "funds"; }
  get amounts() { return this.isFund ? [{key:"aum_usd",label:"AUM (USD)",min:0}, {key:"fund_size_usd",label:"Fund size (USD)",min:0}] : [{ key: "total_funding_usd", label: "Total funding (USD)", min: 0 }, { key: "last_valuation_usd", label: "Last disclosed valuation (USD)", min: 1 }]; }
  get textFields() {
    return [...(this.isFund ? [
      {key:"manager_name", label:"Manager / management firm",type:"text"},
      {key:"manager_url", label:"Manager URL",type:"url"},
      {key:"strategy_focus", label:"Strategy — broad type, e.g. VC, real estate or litigation",type:"text"},
      {key:"vintage_year", label:"Vintage / inception year",type:"number"},
      {key:"fund_life", label:"Fund Life — year range, stated term, extensions or evergreen",type:"text"},
      {key:"fund_domicile", label:"Fund domicile",type:"text"},
    ] : []), {key:"facts_as_of",label:"Facts as of",type:"date"}, {key:"source_url",label:"Source URL",type:"url"}];
  }
  get entityTypes() { return [{id:"company",name:"Company"},{id:"spv",name:"SPV"}]; }
  get fundSizeBases() { return [{id:"commitments",name:"Commitments"},{id:"raised",name:"Raised"},{id:"target",name:"Target"}]; }
  @action async load() {
    const endpoint = this.endpoint;
    this.failed = false;
    this.data = null;
    this.values = {};
    this.saved = false;
    try {
      const data = await ajax(endpoint);
      if (!this.isDestroying && endpoint === this.endpoint) { this.data = data; this.values = data.company; }
    } catch { if (!this.isDestroying && endpoint === this.endpoint) this.failed = true; }
  }
  @action change(key, event) { this.setValue(key, event.target.value); }
  @action setValue(key, value) { this.values = { ...this.values, [key]: value }; this.saved = false; }
  @action async save(event) {
    event.preventDefault();
    const endpoint = this.endpoint;
    this.saving = true;
    this.saved = false;
    try {
      const data = await ajax(endpoint, { type: "PUT", contentType: "application/json", data: JSON.stringify({ company: this.values }) });
      if (!this.isDestroying && endpoint === this.endpoint) { this.values = data.company; this.saved = true; }
    } catch (error) { if (!this.isDestroying && endpoint === this.endpoint) popupAjaxError(error); }
    finally { if (!this.isDestroying && endpoint === this.endpoint) this.saving = false; }
  }
  <template>
    {{#if this.visible}}
      <section class="details svdex-company-admin-fields" aria-label="Company details" {{didInsert this.load}} {{didUpdate this.load @outletArgs.model.id}}>
        <h2>Company details</h2>
        {{#if this.failed}}
          <p class="alert alert-error">Could not load company details.</p><DButton @translatedLabel="Retry" @action={{this.load}} />
        {{else if this.data}}
          <form {{on "submit" this.save}}>
            {{#each this.amounts as |field|}}
              <div class="display-row">
                <label class="field" for="svdex-company-{{field.key}}">{{field.label}}</label>
                <div class="value"><input id="svdex-company-{{field.key}}" type="number" min={{field.min}} max="9007199254740991" step="1" value={{get this.values field.key}} {{on "input" (fn this.change field.key)}} /></div>
              </div>
            {{/each}}
            <div class="display-row">
              <label class="field" for="svdex-company-sector">Sector</label>
              <div class="value"><ComboBox @id="svdex-company-sector" @content={{this.data.sectors}} @value={{this.values.sector_tag_id}} @onChange={{fn this.setValue "sector_tag_id"}} @options={{hash none="svdex.company.none" clearable=true}} /></div>
            </div>
            <div class="display-row">
              <label class="field" for="svdex-company-headquarters">Headquarters country</label>
              <div class="value"><input id="svdex-company-headquarters" type="text" maxlength="80" value={{this.values.headquarters_country}} {{on "input" (fn this.change "headquarters_country")}} /></div>
            </div>
            <div class="display-row">
              <label class="field" for="svdex-company-stage">Stage</label>
              <div class="value"><ComboBox @id="svdex-company-stage" @content={{this.data.stages}} @value={{this.values.stage}} @onChange={{fn this.setValue "stage"}} @options={{hash none="svdex.company.none" clearable=true}} /></div>
            </div>
            <div class="display-row">
              <label class="field" for="svdex-company-tag">Company tag</label>
              <div class="value"><ComboBox @id="svdex-company-tag" @content={{this.data.companies}} @value={{this.values.company_tag_id}} @onChange={{fn this.setValue "company_tag_id"}} @options={{hash none="svdex.company.none" clearable=true}} /></div>
            </div>
            {{#if this.isFund}}
              <div class="display-row"><label class="field" for="svdex-fund-size-basis">Fund size basis</label><div class="value"><ComboBox @id="svdex-fund-size-basis" @content={{this.fundSizeBases}} @value={{this.values.fund_size_basis}} @onChange={{fn this.setValue "fund_size_basis"}} @options={{hash none="svdex.company.none" clearable=true}} /></div></div>
            {{else}}
              <div class="display-row"><label class="field" for="svdex-entity-type">Entity type</label><div class="value"><ComboBox @id="svdex-entity-type" @content={{this.entityTypes}} @value={{this.values.entity_type}} @onChange={{fn this.setValue "entity_type"}} @options={{hash none="svdex.company.none" clearable=true}} /></div></div>
            {{/if}}
            {{#each this.textFields as |field|}}
              <div class="display-row"><label class="field" for="svdex-company-{{field.key}}">{{field.label}}</label><div class="value"><input id="svdex-company-{{field.key}}" type={{field.type}} value={{get this.values field.key}} {{on "input" (fn this.change field.key)}} /></div></div>
            {{/each}}
            <h3>Key People</h3>
            <p>Enter names and roles from verified public sources. Associate an account only after confirming it belongs to that person.</p>
            <AdminReferences @entries={{this.values.key_people}} @onChange={{fn this.setValue "key_people"}} @addLabel="Add person" />
            <h3>Related entities</h3>
            <p>Use Underlying, Sponsor or Manager as the role. An SPV keeps its own financial facts; it does not inherit facts from these entities.</p>
            <AdminReferences @entries={{this.values.related_entities}} @onChange={{fn this.setValue "related_entities"}} @addLabel="Add entity" />
            <p>Company-wide facts. For funds, Location is the investment manager’s headquarters, not fund domicile or investment geography. The directory shows headquarters country; the profile location can include city and country. Open offerings counts active, visible topics linked through the linked company tag. Leave undisclosed values empty. Valuation means last disclosed valuation, not a SAFE cap or an estimate. Fund Life records stated terms; no maturity is calculated from vintage.</p>
            <DButton @type="submit" @class="btn-primary" @translatedLabel="Save company details" @disabled={{this.saving}} @isLoading={{this.saving}} />
            {{#if this.saved}}<span role="status">Saved</span>{{/if}}
          </form>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
