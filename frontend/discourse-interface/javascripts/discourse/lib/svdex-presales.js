export const PRESALE_FIELDS = [
  { key: "summary", name: "Summary", max: 180, hint: "What is the product?" },
  { key: "price", name: "Price", max: 80, hint: "For example, $99 per item or $120 per year" },
  { key: "includes", name: "What buyers receive", max: 120, hint: "Product, quantity or period of access" },
  { key: "delivery", name: "Expected delivery", max: 80, hint: "Delivery window or access start date" },
  { key: "terms", name: "Other terms", max: 240, hint: "Shipping, cancellation or other conditions" },
];
export function isPresaleCategory(id, settings) {
  return Number(id) > 0 && Number(id) === Number(settings.svdex_presales_category_id);
}
export function presaleTerms(data = {}) {
  const price = data.price?.trim();
  return { primary: price || "Price not set", secondary: [data.includes, data.delivery].map(value => value?.trim()).filter(Boolean).join(" · "), progress: null, missing: !price };
}
