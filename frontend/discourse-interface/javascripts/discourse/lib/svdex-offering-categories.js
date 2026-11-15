export function isOfferingCategory(id, settings) {
  return Number(id) > 0 && [settings.svdex_listings_category_id, settings.svdex_public_offerings_category_id, settings.svdex_private_offerings_category_id].some(value => Number(value) === Number(id));
}

export function composerCategoryScope(categoryId, settings, discussionId, originUrl = "") {
  const path = originUrl.split("?")[0].replace(/\/$/, "") || "/";
  if (originUrl && (path === "/" || /^\/(latest|top|all-forums|new|unread|unseen|hot|posted)(\/|$)/.test(path))) return "community";
  if (isOfferingCategory(categoryId, settings)) return "offerings";
  return Number(categoryId) > 0 && Number(categoryId) === Number(discussionId) ? "community" : "unrestricted";
}
export function composerCategoryChoices(content, scope, settings) {
  const parent = Number(settings.svdex_listings_category_id);
  const children = [Number(settings.svdex_public_offerings_category_id), Number(settings.svdex_private_offerings_category_id)];
  return content.filter(category => Number(category.id) !== parent &&
    (scope === "offerings" ? children.includes(Number(category.id)) : scope === "community" ? !isOfferingCategory(category.id, settings) : true));
}
