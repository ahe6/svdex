import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

export default class CompanyCorrection extends Component {
  @tracked values;
  @tracked saving = false;
  constructor() {
    super(...arguments);
    const { profile, correction } = this.args.model;
    this.values = { name: profile.name, summary: profile.summary, revision: correction.revision,
      ...Object.fromEntries(Object.entries(correction.financials).map(([key, value]) => [key, value ?? ""])), reason: "" };
  }
  fields = [
    { key: "name", label: "Company name", max: 120, type: "text" },
    { key: "summary", label: "Summary", max: 180, type: "text" },
    { key: "total_funding_usd", label: "Total funding (USD)", type: "number", min: 0 },
    { key: "last_valuation_usd", label: "Last valuation (USD)", type: "number", min: 1 },
    { key: "as_of", label: "Financial figures as of", type: "date" },
    { key: "source_url", label: "Financial source URL", type: "url" },
  ];
  get identityFields() { return this.fields.slice(0, 2); }
  get financialFields() { return this.fields.slice(2); }
  @action update(key, event) { this.values = { ...this.values, [key]: event.target.value }; }
  @action async submit(event) {
    event.preventDefault();
    this.saving = true;
    try {
      const data = await ajax(`/company-profiles/${encodeURIComponent(this.args.model.profile.slug)}/suggestions.json`, {
        type: "POST", contentType: "application/json", data: JSON.stringify({ suggestion: this.values }),
      });
      this.args.closeModal();
      DiscourseURL.routeTo(data.url);
    } catch (error) { popupAjaxError(error); }
    finally { this.saving = false; }
  }
  <template>
    <DModal @title="Suggest changes" @closeModal={{@closeModal}}>
      <:body>
        <p>Staff review corrections before updating the profile.</p>
        <form id="svdex-company-correction" {{on "submit" this.submit}}>
          {{#each this.identityFields as |field|}}
            <div class="control-group"><label for="company-correction-{{field.key}}">{{field.label}}</label>
              <input id="company-correction-{{field.key}}" type={{field.type}} min={{field.min}} step="1" maxlength={{field.max}} value={{get this.values field.key}} disabled={{this.saving}} {{on "input" (fn this.update field.key)}} />
            </div>
          {{/each}}
          <div class="control-group"><label for="company-correction-reason">What changed, and where can we verify it?</label>
            <textarea id="company-correction-reason" minlength="5" maxlength="1000" required value={{this.values.reason}} disabled={{this.saving}} {{on "input" (fn this.update "reason")}}></textarea>
          </div>
          <details>
            <summary>Financial figures</summary>
            <p>Leave unknown financial figures blank.</p>
            {{#each this.financialFields as |field|}}
              <div class="control-group"><label for="company-correction-{{field.key}}">{{field.label}}</label>
                <input id="company-correction-{{field.key}}" type={{field.type}} min={{field.min}} step="1" value={{get this.values field.key}} disabled={{this.saving}} {{on "input" (fn this.update field.key)}} />
              </div>
            {{/each}}
          </details>
        </form>
      </:body>
      <:footer><DButton @type="submit" form="svdex-company-correction" @translatedLabel="Submit for review" @disabled={{this.saving}} class="btn-primary" /><DButton @translatedLabel="Cancel" @action={{@closeModal}} /></:footer>
    </DModal>
  </template>
}
