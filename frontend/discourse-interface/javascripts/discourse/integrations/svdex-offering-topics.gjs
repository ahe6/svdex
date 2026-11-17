import PresaleFields from "../components/svdex-presale-fields.gjs";
import { isPresaleCategory } from "../lib/svdex-presales";
import moment from "moment";
import PostEventBuilder from "discourse/plugins/discourse-events/discourse/components/modal/post-event-builder";
import DiscoursePostEventEvent from "discourse/plugins/discourse-events/discourse/models/discourse-post-event-event";
import { needsEventBuilder } from "../lib/svdex-new-event";
import { trustHTML } from "@ember/template";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import { homeOfferColumn, HomeOfferHeader } from "../components/svdex-home-offer-details.gjs";
import ListingHomePreview from "../components/svdex-listing-home-preview.gjs";
import ListingOverview from "../components/svdex-listing-overview.gjs";
import PostBid from "../components/svdex-post-bid.gjs";
import { isOfferingCategory, composerCategoryScope, composerCategoryChoices } from "../lib/svdex-offering-categories";
import OfferingMobileCard from "../components/svdex-offering-mobile-card.gjs";
import ListingFields from "../components/svdex-listing-fields.gjs";
import OfferingsEmptyState from "../components/svdex-offerings-empty-state.gjs";

export default function registerOfferingTopics(api, { settings, router, site }) {
  const composerScopes = new WeakMap();
  const scopeFor = categoryId => composerCategoryScope(categoryId, settings, site.categories.find(category => category.slug === "discussion")?.id, router.currentURL);
  api.modifyClass("service:composer", Base => class extends Base {
    async openNewTopic(options = {}) {
      const currentUser = api.getCurrentUser();
      if (needsEventBuilder(options, settings, currentUser)) {
        const timezone = currentUser.user_option?.timezone || moment.tz.guess();
        const start = moment.tz(moment(), timezone).startOf("hour").add(1, "hour");
        const event = DiscoursePostEventEvent.create({ status: "public", starts_at: start, ends_at: start.clone().add(1, "hour"), timezone });
        api.container.lookup("service:modal").show(PostEventBuilder, { model: {
          event,
          toolbarEvent: { addText: body => this.openNewTopic({ ...options, body, title: event.name || options.title }) },
        } });
        return;
      }
      const originScope = scopeFor(options.category?.id);
      const previous = this.model;
      const result = await super.openNewTopic(options);
      if (this.model && (this.model !== previous || Number(this.model.categoryId) === Number(options.category?.id))) {
        const savedScope = this.model.svdex_category_scope;
        const scope = ["offerings", "presales", "community"].includes(savedScope) ? savedScope : originScope;
        this.model.set("svdex_category_scope", scope);
        composerScopes.set(this.model, scope);
      }
      return result;
    }
  });
  api.modifyClass("component:category-chooser", Base => class extends Base {
    modifySelection(content) {
      const selection = super.modifySelection(content);
      const composer = api.container.lookup("service:composer");
      const children = [Number(settings.svdex_public_offerings_category_id), Number(settings.svdex_private_offerings_category_id)];
      if (this.onChange !== composer.updateCategory || !children.includes(Number(this.value))) return selection;
      const category = site.categories.find(item => Number(item.id) === Number(this.value));
      return category ? { ...selection, label: trustHTML(categoryBadgeHTML(category, { link: false, hideParent: true, allowUncategorized: true })) } : selection;
    }
  });
  // Filter only native authorized results, scoped to the originating composer.
  api.modifySelectKit("category-chooser").replaceContent((component, content) => {
    if (!component.element?.closest("#reply-control")) return content;
    const model = api.container.lookup("service:composer").model;
    const savedScope = model?.svdex_category_scope;
    const scope = composerScopes.get(model) || (["offerings", "presales", "community", "unrestricted"].includes(savedScope) ? savedScope : scopeFor(model?.categoryId));
    return composerCategoryChoices(content, scope, settings);
  });
  api.registerValueTransformer("post-menu-buttons", ({ value: dag, context: { buttonKeys, collapsedButtons } }) => {
    dag.add("svdex-bid", PostBid, { before: buttonKeys.REPLY });
    collapsedButtons.show("svdex-bid");
  });
  api.registerValueTransformer("create-topic-label", ({ value, context }) => {
    if ((value === "topic.create" || value === "") && isPresaleCategory(context.category?.id, settings)) return "svdex.new_presale";
    if ((value === "topic.create" || value === "") && Number(context.category?.id) === Number(settings.svdex_events_category_id)) return "discourse_post_event.new_event";
    if ((value === "topic.create" || value === "") && isOfferingCategory(context.category?.id, settings)) return "svdex.new_offering";
    // Core uses an empty mobile label for the icon-only button. Keep its
    // accessible name while the theme preserves the same compact appearance.
    return value === "" ? "topic.create" : value;
  });
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
  api.renderInOutlet("composer-fields", PresaleFields);
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
    if (isOfferingCategory(context.category?.id, settings) || isPresaleCategory(context.category?.id, settings)) value.push("svdex-listing-topics");
    return value;
  });
  api.registerValueTransformer("topic-list-item-class", ({ value, context }) => {
    if (context.topic.svdex_listing || context.topic.svdex_presale) value.push("svdex-listing-topic");
    return value;
  });
}
