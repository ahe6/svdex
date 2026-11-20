import { usdCentsInput, formatUsdCents } from "../lib/svdex-financial-format";
import { getOwner } from "@ember/owner";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import InterestOrganizationSelect from "./svdex-interest-organization-select.gjs";
import { array } from "@ember/helper";
import { hash } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

export class InterestModal extends Component {
  @service siteSettings;
  @tracked organization;
  request = 0;
  sides = [{id: "buy", name: "Buy interest"}, {id: "sell", name: "Sell interest"}];
  get organizationNoun() { return this.args.model.kind === "funds" ? "Fund" : "Company"; }
  get searchLabel() { return this.args.model.kind === "funds" ? "Search funds" : "Search companies"; }
  @tracked own = [];
  @tracked capacity = {};
  @tracked savedPending = false;
  @tracked documentsReady = false;
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
    if (this.args.model.chooseOrganization) this.loading = false;
  }
  markets = [{id: "either", name: "Primary or secondary"}, {id: "primary", name: "Primary financing"}, {id: "secondary", name: "Secondary purchase"}];
  @action changeMarket(value) { this.market = value; this.savedPending = false; }
  get endpoint() { return this.organization?.endpoint || (this.organization ? `/listings/interests/${this.organization.id}` : null) || this.args.model.interestEndpoint || `/listings/interests/${this.args.model.organizationId}`; }
  get isBuy() { return this.side === "buy"; }
  get title() { if (this.args.model.allowDirection) return "Indicate interest"; return this.isBuy ? "Buy interest" : "Sell interest"; }
  get saveLabel() { return this.isBuy ? "Save buy interest" : "Save sell interest"; }
  get fieldsDisabled() { return this.loading || !this.loaded; }
  get saveDisabled() { return this.loading || !this.loaded || !this.confirmation || !(Number(this.amount) > 0); }
  get needsReview() { return this.existing?.active && this.existing?.verification?.state !== "verified"; }
  get capacityNote() {
    const review = this.capacity[this.side];
    if (review?.state === "verified") return `Capacity reviewed up to ${formatUsdCents(review.amount_cents)} through ${review.expires_on}. Larger indications need another review.`;
    if (review?.state === "expired") return "Your capacity review expired. A new review is needed for public totals.";
    if (review?.state === "revoked") return "Your previous capacity review is no longer active.";
    return this.side === "buy" ? "Public totals include only amounts covered by a current buying-capacity review." : "Public totals include only amounts covered by a current review of your holding in this company or fund.";
  }
  get existing() { return this.own.find(row => row.side === this.side); }
  get editHint() {
    if (!this.existing) return "";
    if (this.existing.withdrawn_at) return "Your previous indication was withdrawn. Saving records a new current amount.";
    if (!this.existing.active) return "Your previous indication expired. Saving renews it for 30 days.";
    return `Saving replaces your current ${this.side} interest.`;
  }
  @action async chooseOrganization(_id, item) {
    ++this.request;
    this.organization = item;
    this.loading = false;
    this.own = [];
    this.capacity = {};
    this.documentsReady = false;
    this.savedPending = false;
    this.loaded = false;
    this.error = "";
    this.selectSide();
    if (item) await this.load();
  }
  @action changeSide(value) {
    if (!["buy", "sell"].includes(value)) return;
    this.side = value;
    this.savedPending = false;
    this.selectSide();
  }
  @action async load() {
    if (this.args.model.chooseOrganization && !this.organization) return;
    const request = ++this.request;
    this.loading = true;
    this.loaded = false;
    this.error = "";
    try {
      const data = await ajax(`${this.endpoint}.json`, { data: { topic_id: this.args.model.topicId } });
      if (this.isDestroying || request !== this.request) return;
      this.own = data.interest;
      this.capacity = data.capacity || {};
      this.documentsReady = data.verification_documents_ready === true;
      this.selectSide();
      this.loaded = true;
      return data;
    } catch {
      if (request === this.request) this.error = "Your interest could not be loaded. Please try again.";
    } finally { if (request === this.request) this.loading = false; }
  }
  @action selectSide() {
    const row = this.own.find(record => record.side === this.side);
    this.amount = usdCentsInput(row?.amount_cents);
    this.market = this.side === "sell" ? "secondary" : row?.market || "either";
    this.confirmation = false;
  }
  @action update(event) {
    this.savedPending = false;
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
        if (this.siteSettings.svdex_interest_public_totals && this.needsReview) this.savedPending = true;
        else this.args.closeModal();
      }
    } catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  @action async requestReview() {
    if (!this.existing) return;
    if (this.amount !== usdCentsInput(this.existing.amount_cents)) { this.error = "Save your amount before requesting verification."; return; }
    this.loading = true;
    try {
      const result = await ajax(`/listings/interest-verifications/requests/${this.existing.id}.json`, { type: "POST" });
      this.args.closeModal();
      DiscourseURL.routeTo(result.url);
    } catch (error) { popupAjaxError(error); }
    finally { this.loading = false; }
  }
  <template>
    <DModal @title={{this.title}} @closeModal={{@closeModal}} class="svdex-interest-modal">
      <:body>
        <div {{didInsert this.load}}>
          {{#if @model.chooseOrganization}}
          <div class="control-group"><label for="svdex-interest-organization">{{this.organizationNoun}}</label>
            <InterestOrganizationSelect @id="svdex-interest-organization" @kind={{@model.kind}} @independent={{@model.independent}} @value={{this.organization.id}} @content={{if this.organization (array this.organization)}} @onChange={{this.chooseOrganization}} @options={{hash filterable=true translatedNone=this.searchLabel clearable=true disabled=this.loading}} />
          </div>
          {{else}}<p class="svdex-interest-context"><strong>{{if @model.topicTitle @model.topicTitle @model.organizationName}}</strong></p>{{/if}}
          {{#if @model.allowDirection}}<div class="control-group"><label for="svdex-interest-direction">Direction</label><ComboBox @id="svdex-interest-direction" @value={{this.side}} @content={{this.sides}} @onChange={{this.changeSide}} @options={{hash filterable=false disabled=this.loading}} /></div>{{/if}}
          {{#if this.savedPending}}<p role="status">{{if this.documentsReady "Saved privately. Request verification to include this amount in public totals." "Saved privately. Document verification is not available yet."}}</p>{{/if}}
          <p class="svdex-interest-description">{{if @model.topicTitle "Nonbinding interest in this offering, valid for 30 days." "General interest, independent of an offering. Valid for 30 days."}}</p>
          <div class="control-group">
            <label for="svdex-interest-amount">Amount (USD)</label>
            <input id="svdex-interest-amount" type="number" name="amount" min="0.01" step="0.01" inputmode="decimal" value={{this.amount}} disabled={{this.fieldsDisabled}} {{on "input" this.update}} />
            {{#if this.editHint}}<p class="svdex-interest-hint">{{this.editHint}}</p>{{/if}}
          </div>
          {{#if this.isBuy}}
            <div class="control-group">
              <label for="svdex-interest-market">Market</label>
              <ComboBox @id="svdex-interest-market" @value={{this.market}} @content={{this.markets}} @onChange={{this.changeMarket}} @options={{hash translatedName="Market" disabled=this.fieldsDisabled}} />
            </div>
          {{/if}}
          {{#if this.siteSettings.svdex_interest_public_totals}}<p class="svdex-interest-hint">{{this.capacityNote}}</p>{{/if}}
          {{#if this.documentsReady}}{{#if this.needsReview}}{{#unless this.savedPending}}<DButton class="btn-link" @translatedLabel="Request verification" @action={{this.requestReview}} @disabled={{this.loading}} />{{/unless}}{{/if}}{{/if}}
          <label class="checkbox-label svdex-interest-consent">
            <input type="checkbox" name="confirmation" checked={{this.confirmation}} disabled={{this.fieldsDisabled}} {{on "change" this.update}} />
            <span>{{if this.siteSettings.svdex_interest_public_totals "This is my current nonbinding interest, and I agree to include this amount in public aggregate totals after staff capacity verification. It is not an order or investment commitment." "This is my current nonbinding interest, not an order or investment commitment."}}</span>
          </label>
          <p class="svdex-interest-hint">Private to you and SVDEX staff. Manage or withdraw in <a href="/my/activity/interest">My Interests</a>.</p>
          {{#if this.error}}<p class="alert alert-error" role="alert">{{this.error}}</p>{{/if}}
          {{#if this.error}}{{#unless this.loading}}<DButton @translatedLabel="Try again" @action={{this.load}} />{{/unless}}{{/if}}
        </div>
      </:body>
      <:footer>
        {{#if this.savedPending}}{{#if this.documentsReady}}<DButton class="btn-primary" @translatedLabel="Request verification" @action={{this.requestReview}} @disabled={{this.loading}} />{{/if}}<DButton class="btn-flat" @translatedLabel="Done" @action={{@closeModal}} />
        {{else}}
        <DButton class="btn-primary" @translatedLabel={{this.saveLabel}} @action={{this.save}} @disabled={{this.saveDisabled}} />
        <DButton class="btn-flat" @translatedLabel="Cancel" @action={{@closeModal}} />
        {{/if}}
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
    this.modal.show(InterestModal, { model: { interestEndpoint: this.args.interestEndpoint, organizationId: this.args.organizationId, organizationName: this.args.organizationName, side: this.args.side, allowDirection: this.args.allowDirection, topicId: this.args.topicId, topicTitle: this.args.topicTitle, onChange: this.args.onChange } }); }
  <template>{{#if this.siteSettings.svdex_interest_enabled}}<DButton @icon={{@icon}} @translatedLabel={{if @label @label "Indicate interest"}} @translatedTitle={{@title}} @translatedAriaLabel={{@title}} @action={{this.open}} class={{if @buttonClass @buttonClass "btn-primary"}} />{{/if}}</template>
}
