import Component from "@glimmer/component";
import PersonAffiliations from "./svdex-person-affiliations.gjs";
import DiscoveriesSummary from "./svdex-discoveries-summary.gjs";
export default class PersonProfileSummary extends Component {
  get facts() { const p = this.args.data.person; return [{ label: "Current title", value: p.role }, { label: "Focus", value: p.focus }, { label: "Location", value: p.location }, { label: "All-Time Money", value: p.net_worth?.value, url: p.net_worth?.source }]; }
  <template>
    <div class="svdex-company-profile-summary">
      <section class="top-section stats-section"><h3 class="stats-title">Professional details</h3><ul>{{#each this.facts as |fact|}}<li><div class="user-stat">{{#if fact.url}}<a class="value" href={{fact.url}} target="_blank" rel="noopener noreferrer">{{fact.value}}</a>{{else}}<span class="value">{{or fact.value "—"}}</span>{{/if}}<span class="label">{{fact.label}}</span></div></li>{{/each}}</ul>
      {{#if @data.person.net_worth}}<p>Estimate as of {{@data.person.net_worth.date}}</p>{{/if}}</section>
      <PersonAffiliations @entries={{@data.person.organizations}} />
      <DiscoveriesSummary @credit={{@data.discovery}} />
    </div>
  </template>
}
