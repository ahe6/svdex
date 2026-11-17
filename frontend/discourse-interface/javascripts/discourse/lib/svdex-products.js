export function isProductCategory(id, settings) {
  return Number(id) > 0 && Number(id) === Number(settings.svdex_products_category_id);
}

export function isProductCatalog(id, settings) {
  return isProductCategory(id, settings) || (Number(id) > 0 && Number(id) === Number(settings.svdex_presales_category_id));
}

export function productFilterValue(id, url, settings) {
  if (!isProductCatalog(id, settings)) return "all";
  if (!isProductCategory(id, settings)) return "presales";
  return /\/none(?:\/|$)/.test(url.split("?")[0]) ? "products" : "all";
}
