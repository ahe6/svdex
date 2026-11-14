import { getOwner } from "@ember/owner";
import Component from "@glimmer/component";
import { eq } from "truth-helpers";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { formatFinancialAmount } from "../lib/svdex-financial-format";

export class InterestModal extends Component {
  @service currentUser;
  @service siteSettings;
  @tracked rows = [];
  @tracked own = [];
  @tracked side = "buy";
  @tracked market = "either";
  @tracked amount = "";
  @tracked confirmation = false;
  @tracked loading = true;
  @tracked error = "";
  constructor() {
    super(...arguments);
    this.side = this.args.model.side === "sell" ? "sell" : "buy";
  }
  get endpoint() { return `/listings/interests/${this.args.model.organizationId}`; }
  money(cents) { return formatFinancialAmount(`$${cents / 100}`); }
  get records() { return this.rows.map(row => ({ ...row, amount: this.money(row.amount_cents), state: row.active ? "Active" : row.withdrawn_at ? "Withdrawn" : "Expired" })); }
  @action async load() {
    this.loading = true;
    try { const data = await ajax(`${this.endpoint}.json`, { data: { topic_id: this.args.model.topicId } }); this.rows = data.records; this.own = data.interest; this.selectSide(); return data; }
    catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  @action selectSide() {
    const row = this.own.find(record => record.side === this.side);
    this.amount = row?.amount_cents ? String(row.amount_cents / 100) : "";
    this.market = this.side === "sell" ? "secondary" : row?.market || "either";
    this.confirmation = false;
  }
  @action update(event) {
    const { name, value, checked } = event.target;
    if (["side", "market", "amount", "confirmation"].includes(name)) this[name] = name === "confirmation" ? checked : value;
    if (name === "side") this.selectSide();
  }
  @action async save() {
    if (!this.confirmation) { this.error = "Confirm that this is a nonbinding indication."; return; }
    this.loading = true;
    this.error = "";
    try {
      await ajax(`${this.endpoint}/${this.side}.json`, { type: "PUT", data: { interest: { amount: this.amount, currency: "USD", market: this.market, topic_id: this.args.model.topicId, confirmation: this.siteSettings.svdex_interest_public_totals ? "nonbinding-public-v1" : "nonbinding" } } });
      const data = await this.load();
      if (data) await this.args.model.onChange?.((this.args.model.topicId ? data.offering_totals : data.totals) || {});
    } catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  @action async withdraw() {
    this.loading = true;
    try { await ajax(`${this.endpoint}/${this.side}.json`, { type: "DELETE" }); const data = await this.load(); if (data) await this.args.model.onChange?.((this.args.model.topicId ? data.offering_totals : data.totals) || {}); }
    catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  get canWithdraw() { return this.own.some(row => row.side === this.side && !row.withdrawn_at); }
  <template>
    <DModal @title="Nonbinding interest" @closeModal={{@closeModal}}>
      <:body>
        <div {{didInsert this.load}}>
          {{#if @model.topicTitle}}<p><strong>{{@model.topicTitle}}</strong></p><p>This indication applies to this offering.</p>{{else}}{{#if @model.organizationName}}<p><strong>{{@model.organizationName}}</strong></p>{{/if}}<p>This is general company or fund interest, independent of a particular offering.</p>{{/if}}
          <p>{{if this.siteSettings.svdex_interest_public_totals "Your amount contributes to public buy or sell interest totals. Your identity and individual record remain private to you and SVDEX staff. Private-offering-linked indications are excluded from public totals." "Your indication is private to you and SVDEX staff."}} It is not a commitment, verified funds or an executed trade. Reconfirm within 30 days to keep it current.</p>
          <p>Only one current amount per company or fund and side is counted. Updating it replaces your previous amount, including any linked offering indication.</p>
          <div class="control-group"><label for="svdex-interest-side">Interest</label><select id="svdex-interest-side" name="side" value={{this.side}} {{on "change" this.update}}><option value="buy" selected={{eq this.side "buy"}}>Buy</option><option value="sell" selected={{eq this.side "sell"}}>Secondary sell</option></select></div>
          <div class="control-group"><label for="svdex-interest-amount">Amount (USD)</label><input id="svdex-interest-amount" type="number" name="amount" min="0.01" step="0.01" value={{this.amount}} {{on "input" this.update}} /></div>
          {{#if (eq this.side "buy")}}<div class="control-group"><label for="svdex-interest-market">Buy interest applies to</label><select id="svdex-interest-market" name="market" value={{this.market}} {{on "change" this.update}}><option value="either" selected={{eq this.market "either"}}>Primary or secondary</option><option value="primary" selected={{eq this.market "primary"}}>Primary financing</option><option value="secondary" selected={{eq this.market "secondary"}}>Secondary purchase</option></select></div>{{/if}}
          <label class="checkbox-label"><input type="checkbox" name="confirmation" checked={{this.confirmation}} {{on "change" this.update}} /> {{if this.siteSettings.svdex_interest_public_totals "This is my current nonbinding interest, and I agree to include this amount in public aggregate totals. It is not an order or investment commitment." "This is my current nonbinding interest, not an order or investment commitment."}}</label>
          {{#if this.error}}<p class="alert alert-error" role="alert">{{this.error}}</p>{{/if}}
          {{#if this.records.length}}
            <h3>{{if this.currentUser.staff "Recorded interest" "Your indications"}}</h3>
            <ul>{{#each this.records as |row|}}<li>{{#if row.username}}{{row.username}} · {{/if}}{{row.side}} · {{row.amount}} · {{row.state}}</li>{{/each}}</ul>
          {{/if}}
        </div>
      </:body>
      <:footer><DButton class="btn-primary" @translatedLabel="Save interest" @action={{this.save}} @disabled={{this.loading}} />{{#if this.canWithdraw}}<DButton @translatedLabel="Withdraw interest" @action={{this.withdraw}} @disabled={{this.loading}} />{{/if}}<DButton @translatedLabel="Done" @action={{@closeModal}} /></:footer>
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
