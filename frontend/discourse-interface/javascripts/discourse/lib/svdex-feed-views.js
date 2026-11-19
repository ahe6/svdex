export function feedViews({ category, filterType, settings, routeName, query = {} }) {
  const discussion = category?.slug === "discussion" || routeName === "discovery.discussion-forums";
  const directory = /(?:overview|discussion-forums)/.test(routeName || "");
  const home = !category && !directory && !routeName?.startsWith("chat") && !/upcoming-events/.test(routeName || "") && ["latest", "top"].includes(filterType);
  if (discussion && ["latest", "top", "categories", "chat"].includes(filterType) || home) {
    return { nativeActivity: true, selected: directory || filterType === "chat" ? null : filterType === "top" ? "top" : "latest", views: [["latest", "Latest"], ["top", "Top"]] };
  }
  if (routeName?.startsWith("chat") || /(?:overview|discussion-forums|upcoming-events)/.test(routeName || "")) return null;
  if (!["latest", "top"].includes(filterType)) return null;
  if (Number(category?.id) > 0 && Number(category.id) === Number(settings.svdex_events_category_id)) {
    return { selected: query.svdex_view === "past" ? "past" : "upcoming", views: [["upcoming", "Upcoming"], ["past", "Past"]] };
  }
  return { selected: filterType === "top" ? "top" : query.svdex_view || (category?.slug === "discussion" ? "activity" : "latest"), views: [["latest", "Latest"], ["activity", "Activity"], ["top", "Top"]] };
}

export function feedViewHref(path, query, view) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query || {})) {
    if (value === undefined || value === null || value === "" || ["page", "order", "ascending", "svdex_view", "period"].includes(key)) continue;
    params.set(key, Array.isArray(value) ? value.join(" ") : String(value));
  }
  if (view !== "top") params.set("svdex_view", view);
  return `${path}${params.size ? `?${params}` : ""}`;
}
