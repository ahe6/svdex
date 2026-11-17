import Component from "@glimmer/component";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
export default class PersonAffiliations extends Component {
  get affiliations() { return this.args.outletArgs.user?.svdex_affiliations || []; }
  <template>
    {{#if this.affiliations.length}}
      <section class="top-section svdex-affiliations-summary" aria-label="Affiliations">
        <h3 class="stats-title">Affiliations <span class="svdex-discovery-count">{{this.affiliations.length}}</span></h3>
        <ul class="svdex-discovery-preview">
          {{#each this.affiliations as |organization|}}
            <li><div class="user-info small">
              <div class="user-image"><a href={{organization.url}} aria-hidden="true">{{dAvatar organization imageSize="large"}}</a></div>
              <div class="user-detail"><a href={{organization.url}}>{{organization.name}}</a>{{#if organization.role}}<span>{{organization.role}}</span>{{/if}}</div>
            </div></li>
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}
