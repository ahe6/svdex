import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class CompanySummary extends Component {
  @service router;
  get company() { return this.router.currentRouteName === "companies" ? this.args.outletArgs.user?.svdex_company : undefined; }
  get isSpv() { return this.company?.entity_type === "spv"; }
  get summary() {
    if (this.router.currentRouteName === "people") return this.args.outletArgs.user?.svdex_person?.background;
    return this.router.currentRouteName === "companies" ? this.args.outletArgs.user?.svdex_company_summary : undefined;
  }
  <template>
    {{#if this.isSpv}}<span class="svdex-company-entity-label">SPV</span>{{/if}}
    {{#if this.company.manager_name}}<span class="svdex-company-summary">{{#if this.company.manager_url}}<a href={{this.company.manager_url}}>{{this.company.manager_name}}</a>{{else}}{{this.company.manager_name}}{{/if}}</span>{{/if}}
    {{#if this.summary}}<span class="svdex-company-summary" title={{this.summary}}>{{this.summary}}</span>{{/if}}
  </template>
}
