export function isProductCategory(id, settings) {
  return Number(id) > 0 && Number(id) === Number(settings.svdex_products_category_id);
}

export function isProductCatalog(id, settings) {
  return isProductCategory(id, settings) || (Number(id) > 0 && Number(id) === Number(settings.svdex_presales_category_id));
}

export function productFilterValue(id, url, settings) {
  if (!isProductCatalog(id, settings)) return "all";
  if (!isProductCategory(id, settings)) return "presales";
  const availability = new URL(url, "https://svdex.invalid").searchParams.get("svdex_presales");
  if (availability === "1") return "presales";
  if (availability === "0") return "products";
  return /\/none(?:\/|$)/.test(url.split("?")[0]) ? "products" : "all";
}
