// Sector is a tag too: count unique selected tags only once.
export function activeFilterCount(query = {}, tag, additionalTags = []) {
  const names = new Set([
    ...(Array.isArray(query.tags) ? query.tags : String(query.tags || "").split(/\s+/)),
    tag?.name,
    ...additionalTags.map(value => value?.name || value),
  ].filter(Boolean));
  if (query.no_tags) names.add("none");
  return names.size + Number(Boolean(query.search)) + Number(Boolean(query.svdex_company)) + Number(Boolean(query.svdex_valuation));
}
