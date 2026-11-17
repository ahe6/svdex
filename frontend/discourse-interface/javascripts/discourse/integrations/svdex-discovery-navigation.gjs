import { isPresaleCategory } from "../lib/svdex-presales";
import { isProductCategory } from "../lib/svdex-products";
import registerDiscoveryTabs from "./svdex-discovery-tabs.gjs";
import { isOverviewDirectory } from "../lib/svdex-sector-navigation";
import DiscoveryTopicHeader from "../components/svdex-discovery-topic-header.gjs";
import SectorFilter from "../components/svdex-sector-filter.gjs";
import DiscoverySearch from "../components/svdex-discovery-search.gjs";
import EventsNavigation from "../components/svdex-events-navigation.gjs";
import { isOfferingCategory } from "../lib/svdex-offering-categories";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import DiscourseURL, { getCategoryAndTagUrl } from "discourse/lib/url";
import { ALL_TAGS_ID, NO_TAG_ID, NONE_TAG } from "discourse/select-kit/components/tag-drop";
import MobileCategoryHeading from "../components/svdex-mobile-category-heading.gjs";
import ListingMobileFilters from "../components/svdex-mobile-filters.gjs";
import NavItem, { customNavItemHref } from "discourse/models/nav-item";
import ListingTagGroupFilters from "../components/svdex-tag-group-filters.gjs";

export default function registerDiscoveryNavigation(api, { settings, router, site }) {
  registerDiscoveryTabs(api);
  api.registerValueTransformer("topic-list-columns", ({ value: columns, context }) => {
    if (context.listContext === "discovery" &&
      (isOfferingCategory(context.category?.id, settings) || isPresaleCategory(context.category?.id, settings) || isProductCategory(context.category?.id, settings) ||
        Number(context.category?.id) > 0 && Number(context.category.id) === Number(settings.svdex_events_category_id))) {
      columns.replace("topic", { header: DiscoveryTopicHeader });
    }
    return columns;
  });
  api.renderInOutlet("top-notices", EventsNavigation);
  api.registerValueTransformer("create-topic-icon", () => "plus");
  api.registerValueTransformer("can-create-topic-button", ({ value, context }) => {
    if (isOverviewDirectory(router.currentRouteName) || router.currentRouteName?.startsWith("chat")) return false;
    if (api.getCurrentUser()) return value;
    const category = context.category;
    const publicSubmission = isOfferingCategory(category?.id, settings) || isPresaleCategory(category?.id, settings) ||
      isProductCategory(category?.id, settings) || category?.slug === "discussion" ||
      Number(category?.id) > 0 && Number(category.id) === Number(settings.svdex_events_category_id);
    const home = !category && /^discovery\.(latest|top)$/.test(router.currentRouteName || "");
    return publicSubmission || home || value;
  });
  api.registerBehaviorTransformer("create-topic-button-click", ({ next }) => {
    if (!api.getCurrentUser()) return DiscourseURL.routeTo("/login");
    return next();
  });
  // Suppress only this toolbar's split menu; native create/resume and the
  // current user's actual draft count stay intact elsewhere.
  const singleCreateAction = Base => class extends Base {
    didReceiveAttrs() {
      super.didReceiveAttrs(...arguments);
      this.set("draftCount", 0);
    }
  };
  singleCreateAction.pluginId = "svdex-single-create-action";
  api.modifyClass("component:d-navigation", singleCreateAction);

  const chatShellRoute = Base => class extends Base {
    setupController(controller, model) {
      this.templateName = "svdex-chat";
      super.setupController(controller, model);
    }
  };
  chatShellRoute.pluginId = "svdex-discussion-chat-shell";
  api.modifyClass("route:chat", chatShellRoute);

  // The pinned core search toggle translates its ariaLabel twice. Its
  // visible text already provides the correct accessible name.
  api.onPageChange(() => scheduleOnce("afterRender", null, () => {
    const toggle = document.querySelector(".advanced-filters__toggle");
    if (toggle?.getAttribute("aria-label") === "[en.Advanced filters]") toggle.removeAttribute("aria-label");
  }));

  // One native category selector contains the already-authorized category
  // list, including children. Keep core's hierarchy while editing categories.
  const unifiedCategoryBreadcrumbs = Base => class extends Base {
    get categoryBreadcrumbs() {
      if (this.editingCategory) return super.categoryBreadcrumbs;
      return [{
        category: this.args.category,
        parentCategory: undefined,
        options: this.args.categories,
        isSubcategory: false,
        noSubcategories: this.args.noSubcategories,
        hasOptions: true,
      }];
    }
  };
  unifiedCategoryBreadcrumbs.pluginId = "svdex-unified-category-selector";
  api.modifyClass("component:bread-crumbs", unifiedCategoryBreadcrumbs);

  // Keep the native tag selector and routes, retaining the additional
  // offering filters instead of silently clearing them on tag selection.
  const extendTagDrop = Base => class extends Base {
    @action
    onChange(value, tag) {
      if (!isOfferingCategory(this.currentCategory?.id, settings)) return super.onChange(value, tag);
      const selected = value === NO_TAG_ID ? NONE_TAG : value === ALL_TAGS_ID ? null : (tag?.targetTag || tag);
      const current = new URL(router.currentURL, window.location.origin);
      const params = current.searchParams;
      params.delete("page");
      params.delete("no_tags");
      const remainingTags = (params.get("tags") || "").split(/\s+/).filter(name => name && name !== this.tag?.name);
      if (value !== NO_TAG_ID && remainingTags.length) {
        const names = [...new Set([selected?.name, ...remainingTags].filter(Boolean))];
        params.set("tags", names.join(" "));
        params.set("match_all_tags", "true");
      } else {
        params.delete("tags");
        params.delete("match_all_tags");
      }
      const sort = current.pathname.match(/\/l\/(latest|top|new|unread|unseen|hot|posted)$/)?.[0] || "";
      const path = getCategoryAndTagUrl(this.currentCategory, !this.noSubcategories, selected);
      DiscourseURL.routeToUrl(`${path}${sort}${params.size ? `?${params}` : ""}`);
    }
  };
  extendTagDrop.pluginId = "svdex-offering-tag-filters";
  api.modifyClass("component:tag-drop", extendTagDrop);

  customNavItemHref(item => {
    const query = item.currentRouteQueryParams || {};
    if (!item.category && !item.tag && query.svdex_home === "1" && ["latest", "top"].includes(item.name)) {
      const params = new URLSearchParams({svdex_home: "1"});
      if (query.tags) params.set("tags", Array.isArray(query.tags) ? query.tags.join(" ") : query.tags);
      if (query.no_tags) params.set("no_tags", String(query.no_tags));
      if (query.search) params.set("search", query.search);
      if (query.match_all_tags !== undefined) params.set("match_all_tags", String(query.match_all_tags));
      return `/${item.name}?${params}`;
    }
    const tags = item.currentRouteQueryParams?.tags;
    const company = item.currentRouteQueryParams?.svdex_company;
    const valuation = item.currentRouteQueryParams?.svdex_valuation;
    const active = item.currentRouteQueryParams?.svdex_active;
    if ((!tags && !company && !valuation && !active) || !isOfferingCategory(item.category?.id, settings)) return;
    const path = NavItem.pathFor(item.filterType, { category: item.category, noSubcategories: item.noSubcategories, tag: item.tag });
    const params = new URLSearchParams();
    if (tags) params.set("tags", Array.isArray(tags) ? tags.join(" ") : tags);
    if (company) params.set("svdex_company", company);
    if (valuation) params.set("svdex_valuation", valuation);
    if (active) params.set("svdex_active", active);
    if (item.currentRouteQueryParams.match_all_tags !== undefined) {
      params.set("match_all_tags", String(item.currentRouteQueryParams.match_all_tags));
    }
    return `${path}?${params}`;
  });
  api.renderInOutlet("bread-crumbs-left", ListingTagGroupFilters);
  api.renderInOutlet("before-create-topic-button", DiscoverySearch);
  api.renderInOutlet("before-create-topic-button", SectorFilter);
  api.renderInOutlet("before-create-topic-button", ListingMobileFilters);
  api.renderInOutlet("after-breadcrumbs", MobileCategoryHeading);
}
