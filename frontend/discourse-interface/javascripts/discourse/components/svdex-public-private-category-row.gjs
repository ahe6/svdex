import { cached } from "@glimmer/tracking";
import CategoryRow from "discourse/select-kit/components/category-row";
import { publicPrivateCategory } from "../lib/svdex-public-private-category";
export const PRIVATE_ACCESS_ID = "svdex-private-access-info";
export default class PublicPrivateCategoryRow extends CategoryRow {
  get hideParentCategory() {
    // The unified navigation dropdown already lists Offerings separately.
    // Keep the native row, count and lock, without repeating its parent badge.
    const childIds = [this.siteSettings.svdex_public_offerings_category_id, this.siteSettings.svdex_private_offerings_category_id].map(Number).filter(id => id > 0);
    return childIds.includes(Number(this.args.item?.id)) || super.hideParentCategory;
  }

  @cached
  get category() {
    if (this.args.item?.id === PRIVATE_ACCESS_ID) return publicPrivateCategory();
    const category = super.category;
    if (Number(category?.id) === Number(this.siteSettings.svdex_listings_category_id)) return { ...category, name: "All offerings", displayName: "All offerings" };
    return category;
  }
}
