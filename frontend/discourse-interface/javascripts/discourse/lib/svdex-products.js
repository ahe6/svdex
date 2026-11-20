export function isProductCategory(id, settings) {
  return Number(id) > 0 && Number(id) === Number(settings.svdex_products_category_id);
}

export function isProductCatalog(id, settings) {
  return isProductCategory(id, settings) || (Number(id) > 0 && Number(id) === Number(settings.svdex_presales_category_id));
}

export const PRODUCT_STAGES = [
  { id: "concept", name: "Concept" },
  { id: "presale", name: "Pre-sale" },
  { id: "shipping", name: "Shipping" },
];
