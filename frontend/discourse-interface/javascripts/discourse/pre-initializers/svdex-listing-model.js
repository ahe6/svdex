import { PRESALE_FIELDS, isPresaleCategory } from "../lib/svdex-presales";
import { inferredInstrument } from "../lib/svdex-offering-instruments";
import { isOfferingCategory } from "../lib/svdex-offering-categories";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer from "discourse/models/composer";

const FIELDS = ["svdex_instrument_type", "svdex_summary", "svdex_terms", "svdex_offering_size", "svdex_minimum", "svdex_post_money_valuation_usd", "svdex_interest_rate", "svdex_funds_raised", "svdex_total_funding", "svdex_valuation_cap", "svdex_conversion_discount", "svdex_strike_price", "svdex_expiration"];
const PROPERTIES = ["svdexInstrumentForSave", "svdexSummaryForSave", "svdexTermsForSave", "svdexSizeForSave", "svdexMinimumForSave", "svdexValuationForSave", "svdexInterestForSave", "svdexFundsRaisedForSave", "svdexTotalFundingForSave", "svdexCapForSave", "svdexDiscountForSave", "svdexStrikeForSave", "svdexExpirationForSave"];

const PRESALE_KEYS = PRESALE_FIELDS.map(field => `svdex_presale_${field.key}`);
FIELDS.push(...PRESALE_KEYS);
PROPERTIES.push(...PRESALE_FIELDS.map(field => `svdexPresale${field.key[0].toUpperCase()}${field.key.slice(1)}ForSave`));
function storedValue(model, key) {
  return key.startsWith("svdex_presale_") ? model.topic?.svdex_presale?.[key.replace("svdex_presale_", "")] : model.topic?.svdex_listing?.[key.replace("svdex_", "")];
}

export default {
  name: "svdex-listing-model",
  before: "inject-discourse-objects",
  initialize() {
    withPluginApi(api => {
      if (api.container.lookup("service:site-settings").svdex_listings_category_id === undefined) return;
      api.addModelGetter("composer", "isSvdexListing", function () {
        return this.topicFirstPost && !this.privateMessage && isOfferingCategory(this.categoryId, this.siteSettings);
      });
      api.addModelGetter("composer", "isSvdexPresale", function () {
        return this.topicFirstPost && !this.privateMessage && isPresaleCategory(this.categoryId, this.siteSettings);
      });
      // Composer scope is a draft-only UI preference, never topic metadata.
      api.addModelField("composer", "svdex_category_scope");
      api.serializeToDraft("svdex_category_scope");
      FIELDS.forEach((key, index) => {
        api.addModelField("composer", key);
        api.addModelGetter("composer", PROPERTIES[index], function () {
          const allowed = key.startsWith("svdex_presale_") ? this.isSvdexPresale : this.isSvdexListing;
          if (key === "svdex_instrument_type") return allowed ? (this[key] || inferredInstrument(this.topic?.svdex_listing || {}, this.title || this.topic?.title || "")) : undefined;
          return allowed ? (this[key] ?? storedValue(this, key) ?? "") : undefined;
        });
        api.serializeOnCreate(key, PROPERTIES[index]);
        api.serializeToDraft(key);
        Composer.serializeOnUpdate(key, PROPERTIES[index]);
      });
      api.addModelGetter("composer", "canSaveDraft", function () {
        if (this.action === Composer.ADD_TRANSLATION || this.draftSaving || this.disableDrafts) return false;
        const listingContent = (this.isSvdexListing || this.isSvdexPresale) && FIELDS.some(key => Boolean(this[key]?.trim()));
        return Boolean(listingContent || (this.canEditTitle ? (this.title || this.reply) : this.reply));
      });
      api.addModelGetter("composer", "anyDirty", function () {
        return this.replyDirty || (this.canEditTitle && this.titleDirty) || this.hasMetaData ||
          ((this.isSvdexListing || this.isSvdexPresale) && FIELDS.some(key => this[key] !== undefined && this[key] !== (storedValue(this, key) || "")));
      });
    });
  },
};
