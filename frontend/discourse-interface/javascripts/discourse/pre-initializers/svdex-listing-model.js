import { isOfferingCategory } from "../lib/svdex-offering-categories";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer from "discourse/models/composer";

const FIELDS = ["svdex_summary", "svdex_terms", "svdex_offering_size", "svdex_minimum", "svdex_post_money_valuation_usd", "svdex_interest_rate", "svdex_funds_raised", "svdex_total_funding", "svdex_valuation_cap", "svdex_conversion_discount", "svdex_strike_price", "svdex_expiration"];
const PROPERTIES = ["svdexSummaryForSave", "svdexTermsForSave", "svdexSizeForSave", "svdexMinimumForSave", "svdexValuationForSave", "svdexInterestForSave", "svdexFundsRaisedForSave", "svdexTotalFundingForSave", "svdexCapForSave", "svdexDiscountForSave", "svdexStrikeForSave", "svdexExpirationForSave"];

export default {
  name: "svdex-listing-model",
  before: "inject-discourse-objects",
  initialize() {
    withPluginApi(api => {
      if (api.container.lookup("service:site-settings").svdex_listings_category_id === undefined) return;
      api.addModelGetter("composer", "isSvdexListing", function () {
        return this.topicFirstPost && !this.privateMessage && isOfferingCategory(this.categoryId, this.siteSettings);
      });
      FIELDS.forEach((key, index) => {
        api.addModelField("composer", key);
        api.addModelGetter("composer", PROPERTIES[index], function () {
          const allowed = this.isSvdexListing;
          return allowed ? (this[key] ?? this.topic?.svdex_listing?.[key.replace("svdex_", "")] ?? "") : undefined;
        });
        api.serializeOnCreate(key, PROPERTIES[index]);
        api.serializeToDraft(key);
        Composer.serializeOnUpdate(key, PROPERTIES[index]);
      });
      api.addModelGetter("composer", "canSaveDraft", function () {
        if (this.action === Composer.ADD_TRANSLATION || this.draftSaving || this.disableDrafts) return false;
        const listingContent = this.isSvdexListing && FIELDS.some(key => Boolean(this[key]?.trim()));
        return Boolean(listingContent || (this.canEditTitle ? (this.title || this.reply) : this.reply));
      });
      api.addModelGetter("composer", "anyDirty", function () {
        return this.replyDirty || (this.canEditTitle && this.titleDirty) || this.hasMetaData ||
          (this.isSvdexListing && FIELDS.some(key => this[key] !== undefined && this[key] !== (this.topic?.svdex_listing?.[key.replace("svdex_", "")] || "")));
      });
    });
  },
};
