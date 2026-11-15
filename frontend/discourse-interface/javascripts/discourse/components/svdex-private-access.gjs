import Component from "@glimmer/component";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export class PrivateAccessInfo extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;
  get category() { return this.site.categories.find(c => Number(c.id) === Number(this.siteSettings.svdex_private_offerings_category_id)); }
  get requestUrl() {
    const url = this.siteSettings.svdex_private_access_form_url;
    return /^https:\/\/(docs\.google\.com\/forms\/|forms\.gle\/|tally\.so\/r\/)/.test(url || "") ? url : null;
  }
  <template>
    <section class="svdex-private-access-info">
      <h1>{{dIcon "lock"}} Private Offerings &amp; Private Secondaries</h1>
      {{#if this.category}}
        <p>You have access to the private deals area.</p>
        <a class="btn btn-primary" href={{this.category.url}}>View private deals</a>
      {{else}}
        <p>Request access to the private deals area.</p>
        <h2>How to request access</h2>
        <ol>
          <li>Complete the investor questionnaire using your SVDEX account email.</li>
          <li>The team will review your investment experience and interests, and follow up by email with any questions and next steps.</li>
        </ol>
        <p>Access is granted after an individual review by the SVDEX team.</p>
        {{#if this.currentUser}}{{#if this.requestUrl}}<a class="btn btn-primary" href={{this.requestUrl}} target="_blank" rel="noopener noreferrer">Complete questionnaire</a>{{else}}<p>The questionnaire will be available soon.</p>{{/if}}
        {{else}}<p>Log in or create an account to complete the questionnaire.</p><a class="btn btn-primary" href="/login">Log in to request access</a>{{/if}}
      {{/if}}
    </section>
  </template>
}
