export function privateAccessNoticePage(url = "", categories = [], settings = {}) {
  if (!(Number(settings.svdex_listings_category_id) > 0)) return false;
  const path = url.split("?")[0].replace(/\/$/, "") || "/";
  if (path === "/" || /^\/(latest|top|all-forums|discussion-forums|new|unread|unseen|hot|posted|companies|tags|badges|upcoming-events|search|t)(\/|$)/.test(path)) return true;
  if (/^\/u(?:\/[^/]+(?:\/summary)?)?$/.test(path)) return true;
  return categories.some(category =>
    (path === category.url || path.startsWith(`${category.url}/`) || path.startsWith(`/tags${category.url}/`)));
}
