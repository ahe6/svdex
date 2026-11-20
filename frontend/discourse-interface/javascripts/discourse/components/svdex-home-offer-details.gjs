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

export const OfferingTermDetails = <template>
  <div class={{if @singleLineSecondary "svdex-offering-terms svdex-offering-terms--single-line" "svdex-offering-terms"}} ...attributes>
    <div class={{if @terms.missing "svdex-offering-terms__primary svdex-offering-terms__primary--missing" "svdex-offering-terms__primary"}}>{{@terms.primary}}</div>
    {{#if @terms.secondary}}
      <div class="svdex-offering-terms__secondary" title={{if @singleLineSecondary @terms.secondary}}>{{@terms.secondary}}</div>
    {{/if}}
    {{#if @showProgress}}<progress class="svdex-offering-terms__progress" max="100" value={{@terms.progress}} aria-label={{@terms.secondary}}></progress>{{/if}}
  </div>
</template>;

export function homeOfferColumn(Original) {
  return class extends Component {
    get data() { return this.args.topic.svdex_listing || this.args.topic.svdex_presale; }
    get terms() { return this.args.topic.svdex_presale ? presaleTerms(this.data) : offeringTerms(this.data, this.args.topic.title); }
    get showProgress() { return this.terms.progress !== null; }
    <template>
      {{#if this.data}}
        <td class="svdex-home-offer-details topic-list-data">
          <OfferingTermDetails @terms={{this.terms}} @showProgress={{this.showProgress}} />
        </td>
      {{else}}
        <Original @topic={{@topic}} />
      {{/if}}
    </template>
  };
}
