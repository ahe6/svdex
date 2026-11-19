import { usdCentsInput } from "../lib/svdex-financial-format";
import { getOwner } from "@ember/owner";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { hash } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

export class InterestModal extends Component {
  @service siteSettings;
  @tracked own = [];
  @tracked side = "buy";
  @tracked market = "either";
  @tracked amount = "";
  @tracked confirmation = false;
  @tracked loading = true;
  @tracked loaded = false;
  @tracked error = "";
  constructor() {
    super(...arguments);
    this.side = this.args.model.side === "sell" ? "sell" : "buy";
  }
  markets = [{id: "either", name: "Primary or secondary"}, {id: "primary", name: "Primary financing"}, {id: "secondary", name: "Secondary purchase"}];
  @action changeMarket(value) { this.market = value; }
  get endpoint() { return `/listings/interests/${this.args.model.organizationId}`; }
  get isBuy() { return this.side === "buy"; }
  get title() { return this.isBuy ? "Buy interest" : "Sell interest"; }
  get saveLabel() { return this.isBuy ? "Save buy interest" : "Save sell interest"; }
  get saveDisabled() { return this.loading || !this.loaded || !this.confirmation || !(Number(this.amount) > 0); }
  get existing() { return this.own.find(row => row.side === this.side); }
  get editHint() {
    if (!this.existing) return "";
    if (this.existing.withdrawn_at) return "Your previous indication was withdrawn. Saving records a new current amount.";
    if (!this.existing.active) return "Your previous indication expired. Saving renews it for 30 days.";
    return `Saving replaces your current ${this.side} interest.`;
  }
  @action async load() {
    this.loading = true;
    this.loaded = false;
    this.error = "";
    try { const data = await ajax(`${this.endpoint}.json`, { data: { topic_id: this.args.model.topicId } }); this.own = data.interest; this.selectSide(); this.loaded = true; return data; }
    catch { this.error = "Your interest could not be loaded. Please try again."; }
    finally { this.loading = false; }
  }
  @action selectSide() {
    const row = this.own.find(record => record.side === this.side);
    this.amount = usdCentsInput(row?.amount_cents);
    this.market = this.side === "sell" ? "secondary" : row?.market || "either";
    this.confirmation = false;
  }
  @action update(event) {
    const { name, value, checked } = event.target;
    if (["amount", "confirmation"].includes(name)) this[name] = name === "confirmation" ? checked : value;
  }
  @action async save() {
    if (!this.confirmation) { this.error = "Confirm that this is a nonbinding indication."; return; }
    this.loading = true;
    this.error = "";
    try {
      await ajax(`${this.endpoint}/${this.side}.json`, { type: "PUT", data: { interest: { amount: this.amount, currency: "USD", market: this.market, topic_id: this.args.model.topicId, confirmation: this.siteSettings.svdex_interest_public_totals ? "nonbinding-public-v1" : "nonbinding" } } });
      const data = await this.load();
      if (data) {
        await this.args.model.onChange?.((this.args.model.topicId ? data.offering_totals : data.totals) || {});
        this.args.closeModal();
      }
    } catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  <template>
    <DModal @title={{this.title}} @closeModal={{@closeModal}} class="svdex-interest-modal">
      <:body>
        <div {{didInsert this.load}}>
          <p class="svdex-interest-context"><strong>{{if @model.topicTitle @model.topicTitle @model.organizationName}}</strong></p>
          <p class="svdex-interest-description">{{if @model.topicTitle "Nonbinding interest in this offering, valid for 30 days." "General interest, independent of an offering. Valid for 30 days."}}</p>
          <div class="control-group">
            <label for="svdex-interest-amount">Amount (USD)</label>
            <input id="svdex-interest-amount" type="number" name="amount" min="0.01" step="0.01" inputmode="decimal" value={{this.amount}} disabled={{this.loading}} {{on "input" this.update}} />
            {{#if this.editHint}}<p class="svdex-interest-hint">{{this.editHint}}</p>{{/if}}
          </div>
          {{#if this.isBuy}}
            <div class="control-group">
              <label for="svdex-interest-market">Market</label>
              <ComboBox @id="svdex-interest-market" @value={{this.market}} @content={{this.markets}} @onChange={{this.changeMarket}} @options={{hash translatedName="Market" disabled=this.loading}} />
            </div>
          {{/if}}
          <label class="checkbox-label svdex-interest-consent">
            <input type="checkbox" name="confirmation" checked={{this.confirmation}} disabled={{this.loading}} {{on "change" this.update}} />
            <span>{{if this.siteSettings.svdex_interest_public_totals "This is my current nonbinding interest, and I agree to include this amount in public aggregate totals. It is not an order or investment commitment." "This is my current nonbinding interest, not an order or investment commitment."}}</span>
          </label>
          <p class="svdex-interest-hint">Private to you and SVDEX staff. Manage or withdraw in <a href="/my/activity/interest">My Bids</a>.</p>
          {{#if this.error}}<p class="alert alert-error" role="alert">{{this.error}}</p>{{/if}}
          {{#unless this.loaded}}{{#unless this.loading}}<DButton @translatedLabel="Try again" @action={{this.load}} />{{/unless}}{{/unless}}
        </div>
      </:body>
      <:footer>
        <DButton class="btn-primary" @translatedLabel={{this.saveLabel}} @action={{this.save}} @disabled={{this.saveDisabled}} />
        <DButton class="btn-flat" @translatedLabel="Cancel" @action={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
export default class InterestButton extends Component {
  @service modal;
  @service currentUser;
  @service siteSettings;
  @action open() {
    if (!this.currentUser) return getOwner(this).lookup("route:application").send("showLogin");
    this.modal.show(InterestModal, { model: { organizationId: this.args.organizationId, organizationName: this.args.organizationName, side: this.args.side, topicId: this.args.topicId, topicTitle: this.args.topicTitle, onChange: this.args.onChange } }); }
  <template>{{#if this.siteSettings.svdex_interest_enabled}}<DButton @translatedLabel={{if @label @label "Indicate interest"}} @translatedTitle={{@title}} @translatedAriaLabel={{@title}} @action={{this.open}} class={{if @buttonClass @buttonClass "btn-primary"}} />{{/if}}</template>
}
