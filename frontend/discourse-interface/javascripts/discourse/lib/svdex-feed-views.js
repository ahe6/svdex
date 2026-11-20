import { isOfferingCategory } from "./svdex-offering-categories.js";
import { isProductCatalog, isProductCategory } from "./svdex-products.js";
import { isPresaleCategory } from "./svdex-presales.js";

export function catalogTitle(category, settings) {
  const id = category?.id;
  if (isOfferingCategory(id, settings)) return "Offerings";
  if (isProductCategory(id, settings)) return "Products";
  if (isPresaleCategory(id, settings)) return "Pre-sales";
  if (Number(id) > 0 && Number(id) === Number(settings.svdex_events_category_id)) return "Events";
  return null;
}

export function hasSecuritiesDirectory(id, settings) {
  return Number(id) > 0 && [settings.svdex_listings_category_id, settings.svdex_public_offerings_category_id].some(value => Number(value) === Number(id));
}

export function feedViews({ category, filterType, settings, routeName, query = {} }) {
  const discussion = category?.slug === "discussion" || routeName === "discovery.discussion-forums";
  const directory = /(?:overview|discussion-forums)/.test(routeName || "");
  const home = !category && !directory && !routeName?.startsWith("chat") && !/upcoming-events/.test(routeName || "") && ["latest", "top"].includes(filterType);
  if (discussion && ["latest", "top", "categories", "chat"].includes(filterType) || home) {
    return { nativeActivity: true, selected: directory || filterType === "chat" ? null : filterType === "top" ? "top" : "latest", views: [["latest", "Latest"], ["top", "Top"]] };
  }
  if (Number(category?.id) > 0 && Number(category.id) === Number(settings.svdex_events_category_id) &&
      (filterType === "svdex-events-calendar" || /upcoming-events/.test(routeName || ""))) {
    return { selected: null, views: [["upcoming", "Upcoming"]] };
  }
  if (routeName?.startsWith("chat") || /(?:overview|discussion-forums|upcoming-events)/.test(routeName || "")) return null;
  if (!["latest", "top"].includes(filterType)) return null;
  if (Number(category?.id) > 0 && Number(category.id) === Number(settings.svdex_events_category_id)) {
    return { selected: query.svdex_view === "past" ? "past" : "upcoming", views: [["upcoming", "Upcoming"]] };
  }
  if (isProductCategory(category?.id, settings)) {
    const selected = filterType === "top" ? "top" : query.svdex_view === "directory" ? "directory" : "latest";
    return { selected, views: [["latest", "Latest"], ["top", "Top"], ["directory", "All products"]] };
  }
  const directoryLabel = hasSecuritiesDirectory(category?.id, settings) ? "All securities" :
    isPresaleCategory(category?.id, settings) ? "All pre-sales" : null;
  if (directoryLabel) return { selected: query.svdex_view === "directory" ? "directory" : "latest", views: [["latest", "Latest"], ["directory", directoryLabel]] };
  if (isOfferingCategory(category?.id, settings) || isProductCatalog(category?.id, settings)) {
    const selected = filterType === "top" ? "top" : query.svdex_view === "activity" ? null : "latest";
    return { selected, views: [["latest", "Latest"], ["top", "Top"]] };
  }
  return { selected: filterType === "top" ? "top" : query.svdex_view || (category?.slug === "discussion" ? "activity" : "latest"), views: [["latest", "Latest"], ["activity", "Activity"], ["top", "Top"]] };
}

export function feedViewHref(path, query, view) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query || {})) {
    if (value === undefined || value === null || value === "" || ["page", "order", "ascending", "svdex_view", "period"].includes(key)) continue;
    if (view !== "directory" && ["svdex_product_category", "svdex_product_stage", "svdex_product_asc"].includes(key)) continue;
    params.set(key, Array.isArray(value) ? value.join(" ") : String(value));
  }
  if (view !== "top") params.set("svdex_view", view);
  return `${path}${params.size ? `?${params}` : ""}`;
}
