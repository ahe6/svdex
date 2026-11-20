export function privateAccessNoticePage(url = "", settings = {}) {
  if (!(Number(settings.svdex_listings_category_id) > 0)) return false;
  const path = url.split("?")[0].replace(/\/$/, "") || "/";
  return path === "/" || /^\/(latest|top|all-forums|new|unread|unseen|hot|posted)$/.test(path);
}
