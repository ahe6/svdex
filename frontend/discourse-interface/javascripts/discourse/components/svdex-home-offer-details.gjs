import { isPresaleCategory, presaleTerms } from "../lib/svdex-presales";
import { isOfferingCategory } from "../lib/svdex-offering-categories";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { offeringTerms } from "../lib/svdex-offering-terms";

class OfferingContext extends Component {
  @service router;
  @service site;
  @service siteSettings;
  get dedicated() {
    const path = this.router.currentURL.split("?")[0];
    return this.site.categories.some(category => (isOfferingCategory(category.id, this.siteSettings) || isPresaleCategory(category.id, this.siteSettings)) && (path === category.url || path.startsWith(`${category.url}/`) || path.startsWith(`/tags${category.url}/`)));
  }
}
export class HomeOfferHeader extends OfferingContext {
  <template><th class={{if this.dedicated "svdex-home-offer-heading topic-list-data" "posters topic-list-data"}} scope="col">{{#if this.dedicated}}Terms{{else}}<span class="sr-only">Participants or company and offering details</span>{{/if}}</th></template>
}

export function homeOfferColumn(Original) {
  return class extends Component {
    get data() { return this.args.topic.svdex_listing || this.args.topic.svdex_presale; }
    get terms() { return this.args.topic.svdex_presale ? presaleTerms(this.data) : offeringTerms(this.data, this.args.topic.title); }
    get showProgress() { return this.terms.progress !== null; }
    <template>
      {{#if this.data}}
        <td class="svdex-home-offer-details topic-list-data">
            <div class="svdex-offering-terms">
              <div class={{if this.terms.missing "svdex-offering-terms__primary svdex-offering-terms__primary--missing" "svdex-offering-terms__primary"}}>{{this.terms.primary}}</div>
              {{#if this.terms.secondary}}<div class="svdex-offering-terms__secondary">{{this.terms.secondary}}</div>{{/if}}
              {{#if this.showProgress}}<progress class="svdex-offering-terms__progress" max="100" value={{this.terms.progress}} aria-label={{this.terms.secondary}}></progress>{{/if}}
            </div>

        </td>
      {{else}}
        <Original @topic={{@topic}} />
      {{/if}}
    </template>
  };
}
