import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

const repository = "https://github.com/ahe6/svdex";
const entities = { companies: "company", funds: "fund", people: "person", products: "product", securities: "security" };

function blankDocument(kind) {
  const entry = { schema_version: 1, id: "", name: "", summary: "" };
  const sources = [{ url: "", note: "" }];
  if (kind === "companies") {
    return { ...entry, company_tag: null, sector: null, stage: null, location: null,
      financials: { total_funding_usd: null, last_valuation_usd: null, as_of: null, source_url: null }, sources };
  }
  const facts = kind === "products" ? { description: "", status: "launched", company_tag: null } :
    kind === "securities" ? { description: "", instrument_type: "", topic_id: null } : {};
  return { ...entry, tag: kind === "securities" ? null : "", sector: null, location: null, facts, sources };
}

export function githubEditor(kind, id) {
  const folder = `directory/${encodeURIComponent(kind)}`;
  if (id) return `${repository}/edit/main/${folder}/${encodeURIComponent(id)}.json`;
  const template = new URLSearchParams({ value: JSON.stringify(blankDocument(kind), null, 2) });
  return `${repository}/new/main/${folder}?${template}`;
}

export function openCatalogProposal({ currentUser, site, modal }, kind, id) {
  if (currentUser && site.svdex_catalog_proposals_available) {
    return modal.show(CatalogProposal, { model: { kind, id } });
  }
  window.location.assign(githubEditor(kind, id));
}

class CatalogProposal extends Component {
  @tracked document = JSON.stringify(blankDocument(this.args.model.kind), null, 2);
  @tracked sha;
  @tracked loading = Boolean(this.args.model.id);
  @tracked sending = false;
  @tracked error;
  @tracked pullUrl;

  get id() { return this.args.model.id; }
  get kind() { return this.args.model.kind; }
  get title() { return this.id ? `Suggest ${entities[this.kind]} changes` : `Add ${entities[this.kind]}`; }
  get githubUrl() { return githubEditor(this.kind, this.id); }
  get endpoint() {
    return `/directory-proposals/${this.kind}${this.id ? `/${encodeURIComponent(this.id)}` : ""}.json`;
  }
  get disabled() { return this.loading || this.sending || (this.id && !this.sha); }

  @action async load() {
    if (!this.id) return;
    try {
      const draft = await ajax(this.endpoint);
      this.document = draft.document;
      this.sha = draft.sha;
    } catch {
      this.error = "The current file could not be loaded. Open it on GitHub to continue.";
    } finally {
      this.loading = false;
    }
  }

  @action update(event) { this.document = event.target.value; this.error = null; }

  @action async submit() {
    if (this.disabled) return;
    this.sending = true;
    this.error = null;
    try {
      const result = await ajax(this.endpoint, { type: this.id ? "PUT" : "POST", contentType: "application/json",
        data: JSON.stringify({ document: this.document, sha: this.sha }) });
      this.pullUrl = result.url;
    } catch (error) {
      this.error = error.jqXHR?.responseJSON?.errors?.join(" ") || "The pull request could not be opened. Try again or continue on GitHub.";
    } finally {
      this.sending = false;
    }
  }

  <template>
    <DModal @title={{this.title}} @closeModal={{@closeModal}} class="svdex-catalog-proposal">
      <:body>
        <div {{didInsert this.load}}>
          {{#if this.pullUrl}}
            <p role="status">The pull request is ready for review.</p>
          {{else}}
            <p>Your proposal and source links will be public on GitHub. Use public facts and sources.</p>
            {{#if this.error}}<p class="alert alert-error" role="alert">{{this.error}}</p>{{/if}}
            <label for="svdex-directory-document">Directory file</label>
            <textarea id="svdex-directory-document" rows="14" maxlength="65536"
              value={{this.document}} disabled={{this.disabled}} spellcheck="false" {{on "input" this.update}}></textarea>
            <a href="https://github.com/ahe6/svdex/tree/main/directory#readme" target="_blank" rel="noopener noreferrer">File format and source requirements</a>
          {{/if}}
        </div>
      </:body>
      <:footer>
        {{#if this.pullUrl}}
          <DButton @href={{this.pullUrl}} @translatedLabel="View pull request" class="btn-primary" />
        {{else}}
          <DButton @href={{this.githubUrl}} @translatedLabel="Open on GitHub" />
          <DButton @action={{this.submit}} @translatedLabel="Open public pull request" @disabled={{this.disabled}} class="btn-primary" />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}

export default class CatalogProposalAction extends Component {
  @service currentUser;
  @service modal;
  @service site;

  get label() { return this.args.id ? "Suggest changes" : `Add ${entities[this.args.kind]}`; }
  get visibleLabel() { return this.site.mobileView && !this.args.id ? null : this.label; }
  get icon() { return this.args.id ? "pencil" : "plus"; }
  get style() { return this.args.id ? "btn-default" : "btn-primary svdex-company-application"; }
  @action open() { return openCatalogProposal(this, this.args.kind, this.args.id); }

  <template>
    {{#if this.site.svdex_catalog_publishing_ready}}
      <DButton @icon={{this.icon}} @action={{this.open}} @translatedLabel={{this.visibleLabel}}
        @translatedAriaLabel={{this.label}} @translatedTitle={{this.label}} class={{this.style}} ...attributes />
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}

export class CatalogTopicProposalAction extends Component {
  static shouldRender({ post }) {
    return post.post_number === 1 && !post.hidden && !post.deleted_at &&
      Boolean(post.topic?.svdex_catalog_product_id || post.topic?.svdex_catalog_security_id);
  }

  get kind() { return this.args.post.topic.svdex_catalog_security_id ? "securities" : "products"; }
  get id() { return this.args.post.topic.svdex_catalog_security_id || this.args.post.topic.svdex_catalog_product_id; }

  <template>
    <CatalogProposalAction @kind={{this.kind}} @id={{this.id}} ...attributes />
  </template>
}
