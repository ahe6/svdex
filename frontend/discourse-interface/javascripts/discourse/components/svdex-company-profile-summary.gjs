import DiscoveriesSummary from "./svdex-discoveries-summary.gjs";
import InterestButton from "./svdex-interest.gjs";
import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { ajax } from "discourse/lib/ajax";
import DUserStat from "discourse/ui-kit/d-user-stat";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import UserSummaryTopic from "discourse/components/user-summary-topic";
import OrganizationReferences from "./svdex-organization-references.gjs";
import { directoryFacts } from "../lib/svdex-directory-columns";

export default class CompanyProfileSummary extends Component {
  @tracked data;
  @tracked loading = true;
  @tracked failed = false;
  request = 0;
  get profile() { return this.args.data || this.data; }
  get pending() { return this.args.data ? false : this.loading; }
  @action async load() {
    if (this.args.data) return;
    const request = ++this.request;
    this.loading = true;
    this.failed = false;
    this.data = null;
    try {
      const data = await ajax(`/listings/company-profile/${encodeURIComponent(this.args.user.username)}.json`);
      if (!this.isDestroying && request === this.request) this.data = data;
    } catch {
      if (!this.isDestroying && request === this.request) this.failed = true;
    } finally {
      if (!this.isDestroying && request === this.request) this.loading = false;
    }
  }
  @action refresh() { return this.args.data ? this.args.onRefresh?.() : this.load(); }
  get facts() {
    const c = this.profile?.company;
    if (!c) return [];
    const keys = {people:"key_people", buy_interest:"buy_interest", sell_interest:"sell_interest", sector:"sector", valuation:"last_valuation", funding:"total_funding", location:"location", strategy:"strategy_focus", aum:"aum", fund_life:"fund_life", open:"open_offerings"};
    const facts = directoryFacts(c).map(fact => ({
      ...fact,
      label: `svdex.company.${keys[fact.key]}`,
      value: fact.people ? c.key_people?.length || "—" : fact.value,
      url: fact.people ? (c.key_people?.length ? "#svdex-company-key-people" : null) : fact.url,
    }));
    return facts;
  }
  get heading() { return this.profile?.company.kind === "funds" ? "Fund details" : "Company details"; }
  get isSpv() { return this.profile?.company.entity_type === "spv"; }
  get stage() { return this.profile?.company.kind === "funds" ? null : this.profile?.company.stage; }

  <template>
    <div class="svdex-company-profile-summary" {{didInsert this.load}} {{didUpdate this.load @user.id}}>
      <DConditionalLoadingSpinner @condition={{this.pending}}>
        {{#if this.failed}}
          <p class="alert alert-error">Company details could not be loaded.</p>
          <DButton @translatedLabel="Try again" @action={{this.load}} />
        {{else if this.profile}}
          <div class="top-section stats-section">
            <div class="svdex-company-details-header">
            <h3 class="stats-title">{{this.heading}}{{#if this.isSpv}} · SPV{{/if}}</h3>
            {{#if (or @user.id @data.profile.id)}}<div class="svdex-company-summary-actions">
              <InterestButton @interestEndpoint={{@data.interest_endpoint}} @organizationId={{or @data.profile.id @user.id}} @organizationName={{or @data.profile.name @user.name}} @side="buy" @label="Buy interest" @title="Indicate buy interest" @buttonClass="btn-link" @onChange={{this.refresh}} />
              <InterestButton @interestEndpoint={{@data.interest_endpoint}} @organizationId={{or @data.profile.id @user.id}} @organizationName={{or @data.profile.name @user.name}} @side="sell" @label="Sell interest" @title="Indicate sell interest" @buttonClass="btn-link" @onChange={{this.refresh}} />
            </div>{{/if}}
            </div>
            {{#if this.profile.company.manager_name}}<p>Manager: {{#if this.profile.company.manager_url}}<a href={{this.profile.company.manager_url}}>{{this.profile.company.manager_name}}</a>{{else}}{{this.profile.company.manager_name}}{{/if}}</p>{{/if}}
            <ul>
              {{#each this.facts as |fact|}}
                <li class={{if fact.url "linked-stat"}}>
                  {{#if fact.url}}<a href={{fact.url}}><DUserStat @type="string" @label={{fact.label}} @value={{fact.value}} /></a>
                  {{else}}<DUserStat @type="string" @label={{fact.label}} @value={{fact.value}} />{{/if}}
                </li>
              {{/each}}
            </ul>
            {{#if this.stage}}<p>Stage: {{this.stage}}</p>{{/if}}
            {{#if this.profile.company.fund_domicile}}<p>Fund domicile: {{this.profile.company.fund_domicile}}</p>{{/if}}

          </div>
          {{#if this.profile.company.facts_as_of}}<p>Facts as of {{this.profile.company.facts_as_of}}{{#if this.profile.company.source_url}} · <a href={{this.profile.company.source_url}}>Source</a>{{/if}}</p>
          {{else if this.profile.company.source_url}}<p><a href={{this.profile.company.source_url}}>Source</a></p>{{/if}}
          {{#if this.profile.updates.length}}
          <div class="top-section">
            <h3 class="stats-title">Updates</h3>
              <ul>{{#each this.profile.updates as |topic|}}<UserSummaryTopic @topic={{topic}} @url={{topic.url}} @createdAt={{topic.created_at}} @likes={{topic.like_count}} />{{/each}}</ul>
              {{#if this.profile.updates_url}}<p><a class="more" href={{this.profile.updates_url}}>View all updates</a></p>{{/if}}
          </div>
          {{/if}}
          <div class="top-section">
            <div class="top-sub-section pull-left svdex-company-profile-offerings">
              <h3 class="stats-title">Offerings</h3>
              {{#if this.profile.offerings.length}}
                <ul>{{#each this.profile.offerings as |topic|}}<UserSummaryTopic @topic={{topic}} @url={{topic.url}} @createdAt={{topic.created_at}} @likes={{topic.like_count}} />{{/each}}</ul>
                {{#if this.profile.company.offerings_url}}<p><a class="more" href={{this.profile.company.offerings_url}}>View all offerings</a></p>{{/if}}
              {{else}}<p>No offerings yet.</p>{{/if}}
            </div>
            {{#if this.profile.company.key_people.length}}
              <div class="top-sub-section pull-right" id="svdex-company-key-people">
                <h3 class="stats-title">Key People</h3>
                <ul>{{#each this.profile.company.key_people as |person|}}<li><OrganizationReferences @entries={{array person}} /></li>{{/each}}</ul>
              </div>
            {{/if}}
          </div>
          {{#if this.profile.company.related_entities.length}}
            <div class="top-section">
              <div class="top-sub-section">
                <h3 class="stats-title">Related entities</h3>
                <ul>{{#each this.profile.company.related_entities as |entity|}}<li><OrganizationReferences @entries={{array entity}} /></li>{{/each}}</ul>
              </div>
            </div>
          {{/if}}
          <DiscoveriesSummary @user={{@user}} @credit={{@data.discovery}} />
        {{/if}}
      </DConditionalLoadingSpinner>
    </div>
  </template>
}
