export function isOfferingCategory(id, settings) {
  return Number(id) > 0 && [settings.svdex_listings_category_id, settings.svdex_public_offerings_category_id, settings.svdex_private_offerings_category_id].some(value => Number(value) === Number(id));
}
