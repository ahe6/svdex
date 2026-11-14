import { isOfferingCategory } from "../lib/svdex-offering-categories";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";

const FIELDS = [
  { key: "svdex_summary", name: "Summary", hint: "What does the business do? Aim for about ten words.", max: 180 },
  { key: "svdex_post_money_valuation_usd", name: "Post-money valuation (USD)", hint: "Disclosed company valuation in whole US dollars", type: "number", min: 1, limit: 9007199254740991, step: 1 },
  { key: "svdex_total_funding", name: "Total funding", hint: "Company funding raised across all rounds, including currency", max: 80 },
  { key: "svdex_offering_size", name: "Target", hint: "Amount sought in this offering, including currency", max: 80 },
  { key: "svdex_minimum", name: "Minimum", hint: "Minimum investment, including currency", max: 80 },
  { key: "svdex_interest_rate", name: "Interest rate", hint: "Disclosed debt rate and period", max: 80 },
  { key: "svdex_valuation_cap", name: "Valuation cap", hint: "SAFE or convertible cap, including currency", max: 80 },
  { key: "svdex_conversion_discount", name: "Conversion discount", hint: "Disclosed conversion discount, such as 20%", max: 80 },
  { key: "svdex_strike_price", name: "Strike price", hint: "Warrant exercise price, including currency and share basis", max: 80 },
  { key: "svdex_expiration", name: "Expiry", hint: "Warrant expiration date", max: 80 },
  { key: "svdex_terms", name: "Terms", hint: "Other conditions, such as maturity or repayment", max: 120 },
  { key: "svdex_funds_raised", name: "Raised in this offering", hint: "Amount already raised in this offering; separate from company-wide total funding", max: 80 },
];

export default class ListingFields extends Component {
  @service siteSettings;
  get model() { return this.args.outletArgs.model; }
  get visible() {
    return isOfferingCategory(this.model.categoryId, this.siteSettings) &&
      this.model.topicFirstPost && !this.model.privateMessage;
  }
  get fields() {
    return FIELDS.map(field => ({ ...field, type: field.type || "text",
      value: this.model[field.key] ?? this.model.topic?.svdex_listing?.[field.key.replace("svdex_", "")] ?? ""
    }));
  }
  @action update(key, event) {
    this.model.set(key, event.target.value);
    // Let the native draft observer see metadata-only changes as well.
    this.model.notifyPropertyChange("reply");
  }
  <template>
    {{#if this.visible}}
      <fieldset class="svdex-composer-fields">
        <legend>Offering details</legend>
        {{#each this.fields as |field|}}
          <label class="svdex-field">
            <span>{{field.name}}</span>
            <input type={{field.type}} value={{field.value}} maxlength={{field.max}} min={{field.min}} max={{field.limit}} step={{field.step}}
              placeholder={{field.hint}} {{on "input" (fn this.update field.key)}} />
          </label>
        {{/each}}
      </fieldset>
    {{/if}}
  </template>
}
