import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { formatFinancialAmount } from "../lib/svdex-financial-format";

export default class OfferingBidModal extends Component {
  @tracked bid;
  @tracked records = [];
  @tracked amount = "";
  @tracked terms = "";
  @tracked confirmation = false;
  @tracked loading = true;
  @tracked loaded = false;
  @tracked error = "";
  @tracked notice = "";
  get endpoint() { return `/listings/offering-bids/${this.args.model.topicId}.json`; }
  get canWithdraw() { return this.bid && !this.bid.withdrawn_at; }
  get saveDisabled() { return this.loading || !this.loaded || this.args.model.closed; }
  get state() { return this.bid?.withdrawn_at ? "Withdrawn" : this.bid?.active ? "Current" : "Expired"; }
  get rows() { return this.records.map(row => ({...row, amount: formatFinancialAmount(`$${row.amount_cents / 100}`), state: row.withdrawn_at ? "Withdrawn" : row.active ? "Current" : "Expired" })); }
  @action async load() {
    this.loading = true;
    this.loaded = false;
    this.error = "";
    try {
      const data = await ajax(this.endpoint);
      this.bid = data.bid;
      this.records = data.records;
      this.amount = this.bid ? String(this.bid.amount_cents / 100) : "";
      this.terms = this.bid?.proposed_terms || "";
      this.confirmation = false;
      this.loaded = true;
    } catch { this.error = "Your bid could not be loaded. Try again."; }
    finally { this.loading = false; }
  }
  @action update(event) {
    const {name, value, checked} = event.target;
    if (name === "confirmation") this.confirmation = checked;
    if (name === "amount") this.amount = value;
    if (name === "terms") this.terms = value;
    this.notice = "";
  }
  @action async save() {
    this.error = "";
    if (!this.confirmation) { this.error = "Confirm that this is a nonbinding bid."; return; }
    if (!this.amount || !this.terms.trim()) { this.error = "Enter an amount and proposed terms."; return; }
    this.loading = true;
    try {
      await ajax(this.endpoint, {type:"PUT", data:{bid:{amount:this.amount, currency:"USD", proposed_terms:this.terms, confirmation:"nonbinding-bid-v1"}}});
      await this.load();
      this.notice = "Bid submitted.";
      await this.args.model.onChange?.();
    } catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  @action async withdraw() {
    this.loading = true;
    try { await ajax(this.endpoint, {type:"DELETE"}); await this.load(); this.notice = "Bid withdrawn."; await this.args.model.onChange?.(); }
    catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  <template>
    <DModal @title="Submit bid" @closeModal={{@closeModal}} class="svdex-offering-bid-modal">
      <:body>
        <div {{didInsert this.load}}>
          <p><strong>{{@model.topicTitle}}</strong></p>
          {{#if @model.closed}}<p class="alert alert-info">This offering is closed to new or updated bids. You can still withdraw your bid.</p>{{/if}}
          {{#if this.bid}}<p>Your bid: {{this.state}}</p>{{/if}}
          <div class="control-group"><label for="svdex-bid-amount">Amount (USD)</label><input id="svdex-bid-amount" type="number" name="amount" min="0.01" step="0.01" value={{this.amount}} disabled={{this.loading}} {{on "input" this.update}} /></div>
          <div class="control-group"><label for="svdex-bid-terms">Proposed terms</label><textarea id="svdex-bid-terms" name="terms" rows="4" maxlength="2000" value={{this.terms}} disabled={{this.loading}} placeholder="Price per share, valuation, discount, or other terms you propose" {{on "input" this.update}}></textarea></div>
          <label class="checkbox-label"><input type="checkbox" name="confirmation" checked={{this.confirmation}} disabled={{this.loading}} {{on "change" this.update}} /> This is my nonbinding bid, not an order or investment commitment.</label>
          {{#if this.error}}<p class="alert alert-error" role="alert">{{this.error}}</p>{{/if}}
          {{#unless this.loaded}}{{#unless this.loading}}<DButton @translatedLabel="Try again" @action={{this.load}} />{{/unless}}{{/unless}}
          {{#if this.notice}}<p class="alert alert-success" role="status">{{this.notice}}</p>{{/if}}
          {{#if this.rows.length}}
            <h3>Submitted bids</h3>
            <ul>{{#each this.rows as |row|}}<li><p>{{row.username}} · {{row.amount}} · {{row.state}}</p><p class="svdex-bid-terms">{{row.proposed_terms}}</p></li>{{/each}}</ul>
          {{/if}}
        </div>
      </:body>
      <:footer>
        <DButton class="btn-primary" @translatedLabel="Submit bid" @action={{this.save}} @disabled={{this.saveDisabled}} />
        {{#if this.canWithdraw}}<DButton @translatedLabel="Withdraw bid" @action={{this.withdraw}} @disabled={{this.loading}} />{{/if}}
        <DButton @translatedLabel="Done" @action={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
