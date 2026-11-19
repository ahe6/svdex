import { eq } from "truth-helpers";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn, get, hash, array } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { formatUsdCents } from "../lib/svdex-financial-format";

class HoldingTargetSelect extends ComboBox {
  async search(filter) { return (await ajax("/listings/interest-verifications/targets.json", { data: { name: filter } })).targets; }
}
function dateAfter(days) { return new Date(Date.now() + days * 86400000).toISOString().slice(0, 10); }
export default class InterestVerificationAdmin extends Component {
  @tracked records = [];
  @tracked values = { side: "buy", amount: "", checked_on: dateAfter(0), expires_on: dateAfter(90), evidence_reference: "", holding_details: "" };
  @tracked target;
  @tracked saving = false;
  @tracked loaded = false;
  @tracked failed = false;
  @tracked documentsReady = false;
  get userId() { return this.args.outletArgs.model?.id; }
  get endpoint() { return `/listings/interest-verifications/users/${this.userId}.json`; }
  get sell() { return this.values.side === "sell"; }
  sides = [{id: "buy", name: "Buying capacity"}, {id: "sell", name: "Sell holding"}];
  fields = [{key:"amount",label:"Reviewed amount (USD)",type:"number"}, {key:"checked_on",label:"Checked on",type:"date"}, {key:"expires_on",label:"Expires on",type:"date"}, {key:"evidence_reference",label:"Private evidence reference",type:"text"}];
  get rows() { return this.records.map(row => ({ ...row, amount: formatUsdCents(row.amount_cents), status: row.superseded_at ? "Replaced" : row.revoked_at ? "Revoked" : row.expires_on < dateAfter(0) ? "Expired" : "Current", canRevoke: !row.revoked_at && !row.superseded_at })); }
  @action async load() {
    const endpoint = this.endpoint;
    this.loaded = false; this.failed = false;
    try { const data = await ajax(endpoint); if (!this.isDestroying && endpoint === this.endpoint) { this.records = data.records; this.documentsReady = Object.values(data.document_upload_requirements || {}).length > 0 && Object.values(data.document_upload_requirements).every(Boolean); this.loaded = true; } }
    catch { this.failed = true; }
  }
  @action changeSide(side) { this.values = { ...this.values, side }; this.target = null; }
  @action chooseTarget(_id, item) { this.target = item; }
  @action update(key, event) { this.values = { ...this.values, [key]: event.target.value }; }
  @action async save(event) {
    event.preventDefault(); this.saving = true;
    const endpoint = this.endpoint;
    try {
      const data = await ajax(endpoint, { type: "POST", contentType: "application/json", data: JSON.stringify({ verification: { ...this.values,
        target_type: this.sell ? this.target?.target_type : null, target_id: this.sell ? this.target?.target_id : null } }) });
      if (!this.isDestroying && endpoint === this.endpoint) { this.records = data.records; this.values = { ...this.values, amount: "", evidence_reference: "", holding_details: "" }; }
    } catch (error) { popupAjaxError(error); }
    finally { this.saving = false; }
  }
  @action async revoke(row) {
    this.saving = true;
    try { await ajax(`/listings/interest-verifications/${row.id}.json`, { type: "DELETE" }); await this.load(); }
    catch (error) { popupAjaxError(error); }
    finally { this.saving = false; }
  }
  <template>
    {{#if this.userId}}
      <section class="details" aria-label="Interest verification" {{didInsert this.load}} {{didUpdate this.load this.userId}}>
        <h2>Interest verification</h2>
        <p>Capacity checks are private and separate from accreditation. Keep statement contents outside this form; record a private evidence reference.</p>
        {{#if this.failed}}<p class="alert alert-error">Could not load capacity reviews.</p><DButton @translatedLabel="Retry" @action={{this.load}} />{{/if}}
        {{#if this.loaded}}
          {{#unless this.documentsReady}}<p>Document intake is closed until S3 Secure Uploads is configured and tested. You can still record evidence reviewed through another private channel.</p>{{/unless}}
          <form {{on "submit" this.save}}>
            <div class="display-row"><label class="field" for="capacity-side">Review</label><div class="value"><ComboBox @id="capacity-side" @content={{this.sides}} @value={{this.values.side}} @onChange={{this.changeSide}} /></div></div>
            {{#if this.sell}}
              <div class="display-row"><label class="field" for="capacity-target">Company or fund</label><div class="value"><HoldingTargetSelect @id="capacity-target" @value={{this.target.id}} @content={{if this.target (array this.target)}} @onChange={{this.chooseTarget}} @options={{hash filterable=true translatedNone="Search companies and funds"}} /></div></div>
              <div class="display-row"><label class="field" for="capacity-holding">Holding and authority checked</label><div class="value"><textarea id="capacity-holding" minlength="5" maxlength="500" required value={{this.values.holding_details}} {{on "input" (fn this.update "holding_details")}}></textarea></div></div>
            {{/if}}
            {{#each this.fields as |field|}}
              <div class="display-row"><label class="field" for="capacity-{{field.key}}">{{field.label}}</label><div class="value"><input id="capacity-{{field.key}}" type={{field.type}} required min={{if (eq field.key "amount") "0.01"}} step={{if (eq field.key "amount") "0.01"}} maxlength={{if (eq field.key "evidence_reference") 1000}} value={{get this.values field.key}} disabled={{this.saving}} {{on "input" (fn this.update field.key)}} /></div></div>
            {{/each}}
            <DButton @type="submit" @translatedLabel="Record verification" @disabled={{this.saving}} class="btn-primary" />
          </form>
          <details><summary>Review history</summary>
            {{#each this.rows as |row|}}<div class="display-row"><div class="field">{{if (eq row.side "buy") "Buying capacity" "Sell holding"}} · {{row.status}}</div><div class="value"><p>{{row.amount}}{{#if row.target}} · {{row.target.name}}{{/if}}</p><p>{{row.checked_on}}–{{row.expires_on}} · {{row.reviewer}}</p><p>{{row.evidence_reference}}</p>{{#if row.holding_details}}<p>{{row.holding_details}}</p>{{/if}}{{#if row.canRevoke}}<DButton @translatedLabel="Revoke" @action={{fn this.revoke row}} @disabled={{this.saving}} />{{/if}}</div></div>{{/each}}
          </details>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
