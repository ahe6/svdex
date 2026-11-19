import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { avatarImg } from "discourse/lib/avatar-utils";
function organizationLogo(organization) { return trustHTML(avatarImg({ size: "large", avatarTemplate: organization.avatar_template, alt: "", title: organization.name })); }
export default class PersonAffiliations extends Component {
  get affiliations() { return this.args.entries || this.args.outletArgs?.user?.svdex_affiliations || []; }
  <template>
    {{#if this.affiliations.length}}
      <section class="top-section svdex-affiliations-summary" aria-label="Affiliations">
        <h3 class="stats-title">Affiliations <span class="svdex-discovery-count">{{this.affiliations.length}}</span></h3>
        <ul class="svdex-discovery-preview">
          {{#each this.affiliations as |organization|}}
            <li><div class="user-info small">
              <div class="user-image"><a href={{organization.url}} aria-hidden="true">{{organizationLogo organization}}</a></div>
              <div class="user-detail"><a href={{organization.url}}>{{organization.name}}</a>{{#if organization.role}}<span>{{organization.role}}</span>{{/if}}</div>
            </div></li>
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}
