export function isOverviewDirectory(routeName) {
  return /^discovery\.(overview|discussion-forums)(?:\.|$)/.test(routeName || "");
}

export function usesSectorFilter(category, tag, routeName, settings) {
  if (isOverviewDirectory(routeName) || routeName?.startsWith("chat")) return false;
  return category?.slug === "discussion" ||
    (!category && !tag && /^discovery\.(latest|top|overview)(?:\.|$)/.test(routeName || ""));
}

export function sectorDestination({ url, category, mainTag, sectorNames, value, home }) {
  const current = new URL(url, "https://svdex.invalid");
  const params = current.searchParams;
  const sectors = new Set(sectorNames);
  const tags = (params.get("tags") || "").split(/\s+/).filter(name => name && !sectors.has(name));
  if (mainTag && mainTag !== "none" && !sectors.has(mainTag)) tags.unshift(mainTag);
  if (value) tags.push(value);
  const unique = [...new Set(tags)];
  ["tags", "match_all_tags", "no_tags", "page"].forEach(key => params.delete(key));
  if (unique.length) {
    params.set("tags", unique.join(" "));
    params.set("match_all_tags", "true");
  }
  let path = current.pathname;
  if (home) {
    path = current.pathname === "/top" ? "/top" : "/latest";
    if (unique.length) params.set("svdex_home", "1");
    else params.delete("svdex_home");
  } else if (category && mainTag && sectors.has(mainTag)) {
    const mode = current.pathname.match(/\/l\/(latest|top|new|unread|unseen|hot|posted)$/)?.[0] || "";
    path = `${category.url}${mode}`;
  }
  return `${path}${params.size ? `?${params}` : ""}`;
}
