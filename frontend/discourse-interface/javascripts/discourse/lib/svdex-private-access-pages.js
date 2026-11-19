export function organizationDirectoryPage(url = "") {
  return /^\/(?:companies|company-directory|fund-directory)\/?$/.test(url.split("?")[0]);
}

export function privateAccessNoticePage(url = "", categories = [], settings = {}) {
  if (!(Number(settings.svdex_listings_category_id) > 0)) return false;
  const path = url.split("?")[0].replace(/\/$/, "") || "/";
  if (path === "/" || /^\/(latest|top|all-forums|new|unread|unseen|hot|posted)$/.test(path)) return true;
  const offerings = new Set([settings.svdex_listings_category_id, settings.svdex_public_offerings_category_id, settings.svdex_private_offerings_category_id].map(Number).filter(id => id > 0));
  return categories.some(category => offerings.has(Number(category.id)) &&
    (path === category.url || path.startsWith(`${category.url}/`) || path.startsWith(`/tags${category.url}/`)));
}
