import { isPresaleCategory, PRESALE_FIELDS } from "../lib/svdex-presales";
import { isOfferingCategory } from "../lib/svdex-offering-categories";
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { formatFinancialAmount, formatValuation } from "../lib/svdex-financial-format";

export default class ListingOverview extends Component {
  @service siteSettings;
  get isPresale() { const { post, model } = this.args.outletArgs; return Boolean(post?.topic?.svdex_presale) || (model?.type === "ReviewableQueuedPost" && isPresaleCategory(model.category_id ?? model.category?.id, this.siteSettings)); }
  get data() {
    const post = this.args.outletArgs.post;
    const reviewable = this.args.outletArgs.model;
    if (reviewable?.type === "ReviewableQueuedPost" && this.isPresale) return Object.fromEntries(PRESALE_FIELDS.map(field => [field.key, reviewable.payload?.[`svdex_presale_${field.key}`]]));
    if (reviewable?.type === "ReviewableQueuedPost" &&
        isOfferingCategory(reviewable.category_id ?? reviewable.category?.id, this.siteSettings)) {
      const payload = reviewable.payload || {};
      return Object.fromEntries(["summary", "post_money_valuation_usd", "interest_rate", "terms", "offering_size", "funds_raised", "total_funding", "minimum", "valuation_cap", "conversion_discount", "strike_price", "expiration"]
        .map(key => [key, payload[`svdex_${key}`]]));
    }
    if (Number(post?.post_number) === 1 && !post.hidden && !post.deleted && !post.cooked_hidden) {
      return post.topic?.svdex_listing || post.topic?.svdex_presale;
    }
  }
  get summary() { return this.data?.summary?.trim(); }
  get rows() {
    const data = this.data;
    if (!data) return [];
    if (this.isPresale) return PRESALE_FIELDS.filter(field => field.key !== "summary" && data[field.key]?.trim()).map(field => ({ label: field.name, value: data[field.key] }));
    const valuation = formatValuation(data.post_money_valuation_usd);
    const interestRows = !this.siteSettings.svdex_bids_enabled && Object.hasOwn(data, "interest_totals") ? ["buy", "sell"].map(side => ({
      label: `Offering ${side} interest`,
      value: data.interest_totals?.[side] == null ? "—" : formatFinancialAmount(`$${data.interest_totals[side] / 100}`),
    })) : [];
    const rows = [
      { label: "Valuation", value: valuation === "—" ? "" : valuation },
      { label: "Total funding", value: data.total_funding },
      { label: "Target", value: data.offering_size },
      { label: "Minimum", value: data.minimum },
      { label: "Interest rate", value: data.interest_rate },
      { label: "Valuation cap", value: data.valuation_cap },
      { label: "Conversion discount", value: data.conversion_discount },
      { label: "Strike price", value: data.strike_price },
      { label: "Expiry", value: data.expiration },
      { label: "Terms", value: data.terms },
      { label: "Raised in this offering", value: data.funds_raised },
    ].filter(row => row.value?.trim() && !["—", "-"].includes(row.value.trim()));
    return [...rows, ...interestRows];
  }
  get visible() { return this.data && (this.summary || this.rows.length); }
  <template>
    {{#if this.visible}}
      <section class="cooked svdex-topic-overview" aria-label={{if this.isPresale "Pre-sale details" "Company or offering details"}}>
        {{#if this.summary}}<p>{{this.summary}}</p>{{/if}}
        {{#if this.rows.length}}
          <dl>
            {{#each this.rows as |row|}}
              <div><dt>{{row.label}}</dt><dd>{{row.value}}</dd></div>
            {{/each}}
          </dl>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
