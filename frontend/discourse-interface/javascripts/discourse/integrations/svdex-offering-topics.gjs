import { homeOfferColumn, HomeOfferHeader } from "../components/svdex-home-offer-details.gjs";
import ListingHomePreview from "../components/svdex-listing-home-preview.gjs";
import ListingOverview from "../components/svdex-listing-overview.gjs";
import PostBid from "../components/svdex-post-bid.gjs";
import { isOfferingCategory } from "../lib/svdex-offering-categories";
import OfferingMobileCard from "../components/svdex-offering-mobile-card.gjs";
import ListingFields from "../components/svdex-listing-fields.gjs";
import OfferingsEmptyState from "../components/svdex-offerings-empty-state.gjs";

export default function registerOfferingTopics(api, { settings, router, site }) {
  api.registerValueTransformer("post-menu-buttons", ({ value: dag, context: { buttonKeys, collapsedButtons } }) => {
    dag.add("svdex-bid", PostBid, { before: buttonKeys.REPLY });
    collapsedButtons.show("svdex-bid");
  });
  api.registerValueTransformer("create-topic-label", ({ value, context }) =>
    value === "topic.create" && isOfferingCategory(context.category?.id, settings) ? "svdex.new_offering" : value
  );
  api.modifyClass("controller:discovery/list", Base => class extends Base {
    get createTopicTargetCategory() {
      if (Number(this.model.category?.id) === Number(settings.svdex_listings_category_id)) {
        const category = site.categories.find(c => Number(c.id) === Number(settings.svdex_public_offerings_category_id));
        if (category) return category;
      }
      return super.createTopicTargetCategory;
    }
  });
  api.renderInOutlet("discovery-list-area", OfferingsEmptyState);
  api.renderInOutlet("topic-list-item", OfferingMobileCard);
  api.renderInOutlet("composer-fields", ListingFields);
  api.renderInOutlet("topic-list-main-link-bottom", ListingHomePreview);
  api.renderAfterWrapperOutlet("post-content-cooked-html", ListingOverview);
  api.renderInOutlet("after-reviewable-queued-post-body", ListingOverview);
  api.registerValueTransformer("topic-list-columns", ({ value: columns, context }) => {
    // Every desktop topic list shares one offering presentation. Ordinary
    // topics still render the native posters cell through the wrapper.
    if (!site.mobileView) {
      const posters = columns.resolve().find(entry => entry.key === "posters");
      if (posters) columns.replace("posters", {
        header: HomeOfferHeader,
        item: homeOfferColumn(posters.value.item),
      });
      return columns;
    }
    return columns;
  });
  api.registerValueTransformer("topic-list-class", ({ value, context }) => {
    if (isOfferingCategory(context.category?.id, settings)) value.push("svdex-listing-topics");
    return value;
  });
  api.registerValueTransformer("topic-list-item-class", ({ value, context }) => {
    if (context.topic.svdex_listing) value.push("svdex-listing-topic");
    return value;
  });
}
