export const PRESALE_FIELDS = [
  { key: "summary", name: "Summary", max: 180, hint: "What is the product?" },
  { key: "price", name: "Price", max: 80, hint: "$99 per item or year" },
  { key: "includes", name: "What buyers receive", max: 120, hint: "Product or access" },
  { key: "delivery", name: "Expected delivery", max: 80, hint: "e.g. March 2027" },
  { key: "terms", name: "Other terms", max: 240, hint: "Shipping or returns" },
];
export function isPresaleCategory(id, settings) {
  return Number(id) > 0 && Number(id) === Number(settings.svdex_presales_category_id);
}
export function presaleTerms(data = {}) {
  const price = data.price?.trim();
  return { primary: price || "Price not set", secondary: [data.includes, data.delivery].map(value => value?.trim()).filter(Boolean).join(" · "), progress: null, missing: !price };
}
