import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
export default class DiscoveryAdmin extends Component {
  @tracked data;
  @tracked values = {};
  @tracked reason = "";
  @tracked error = false;
  @tracked saving = false;
  @tracked saved = false;
  get visible() { return this.args.outletArgs.model?.svdex_discovery_entity; }
  get endpoint() { return `/listings/discovery-credit/${this.args.outletArgs.model.id}.json`; }
  provenances = [{id:"discovered",name:"Discovered by a contributor"},{id:"self_listed",name:"Self-listed"},{id:"staff_added",name:"Added by SVDEX"},{id:"imported",name:"Imported"}];
  statuses = [{id:"accepted",name:"Accepted"},{id:"withdrawn",name:"Withdrawn"},{id:"disputed",name:"Disputed — hide credit pending review"}];
  get needsContributor() { return ["discovered", "self_listed"].includes(this.values.provenance); }
  get dateKnown() { return Boolean(this.data?.discovery?.listed_at); }
  @action async load() {
    const endpoint = this.endpoint;
    this.data = null; this.error = false; this.saved = false; this.reason = "";
    try { const data = await ajax(endpoint); if (!this.isDestroying && endpoint === this.endpoint) { this.data = data; this.values = data.discovery || {provenance:"staff_added",status:"accepted",contributor:"",listed_at:""}; } }
    catch { if (!this.isDestroying && endpoint === this.endpoint) this.error = true; }
  }
  @action setValue(key, value) { this.values = {...this.values, [key]:value}; this.saved = false; }
  @action input(key, event) { this.setValue(key, event.target.value); }
  @action changeReason(event) { this.reason = event.target.value; this.saved = false; }
  @action async save(event) {
    event.preventDefault(); this.saving = true;
    const endpoint = this.endpoint;
    try {
      const data = await ajax(endpoint,{type:"PUT",contentType:"application/json",data:JSON.stringify({discovery:{...this.values,reason:this.reason}})});
      if (!this.isDestroying && endpoint === this.endpoint) { this.data = data; this.values = data.discovery; this.reason = ""; this.saved = true; }
    } catch (error) { if (!this.isDestroying) popupAjaxError(error); }
    finally { if (!this.isDestroying) this.saving = false; }
  }
  <template>
    {{#if this.visible}}
      <section class="details svdex-discovery-admin" aria-label="Discovery credit" {{didInsert this.load}} {{didUpdate this.load @outletArgs.model.id}}>
        <h2>Discovery credit</h2>
        {{#if this.error}}<p class="alert alert-error">Could not load discovery credit.</p><DButton @translatedLabel="Retry" @action={{this.load}} />
        {{else if this.data}}
          <p>Credit the first substantive listing on SVDEX. Review duplicates and sources before accepting. Profile edits and claims do not change this credit.</p>
          <form {{on "submit" this.save}}>
            <div class="display-row"><label class="field">Source</label><div class="value"><ComboBox @content={{this.provenances}} @value={{this.values.provenance}} @onChange={{fn this.setValue "provenance"}} aria-label="Discovery source" /></div></div>
            {{#if this.needsContributor}}<div class="display-row"><label class="field" for="svdex-discovery-contributor">Contributor username</label><div class="value"><input id="svdex-discovery-contributor" value={{this.values.contributor}} required {{on "input" (fn this.input "contributor")}} /></div></div>{{/if}}
            <div class="display-row"><label class="field" for="svdex-discovery-date">First listed on SVDEX (UTC)</label><div class="value"><input id="svdex-discovery-date" placeholder="YYYY-MM-DDTHH:MM:SSZ" value={{this.values.listed_at}} readonly={{this.dateKnown}} {{on "input" (fn this.input "listed_at")}} /><p>Unknown dates stay blank. Once recorded, the original timestamp is preserved.</p></div></div>
            <div class="display-row"><label class="field">Review status</label><div class="value"><ComboBox @content={{this.statuses}} @value={{this.values.status}} @onChange={{fn this.setValue "status"}} aria-label="Discovery review status" /></div></div>
            <div class="display-row"><label class="field" for="svdex-discovery-reason">Review reason and evidence</label><div class="value"><textarea id="svdex-discovery-reason" minlength="5" maxlength="1000" required value={{this.reason}} {{on "input" this.changeReason}}></textarea></div></div>
            <DButton @type="submit" @translatedLabel="Save discovery credit" @isLoading={{this.saving}} class="btn-primary" />{{#if this.saved}}<span role="status">Saved</span>{{/if}}
          </form>
          <details><summary>Discovery history</summary>
            {{#each this.data.events as |event|}}<div class="display-row"><div class="field">{{event.label}}</div><div class="value"><p>{{event.reason}}</p><time>{{event.created_at}}</time><p>Contributor: {{event.before_state.contributor_user_id}} → {{event.after_state.contributor_user_id}} · Source: {{event.after_state.provenance}} · Status: {{event.after_state.status}}</p></div></div>{{/each}}
          </details>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
