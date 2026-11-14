import { service } from "@ember/service";
import { computed } from "@ember/object";
import CategoriesController from "discourse/controllers/discovery/categories";

export default class DiscussionForumsController extends CategoriesController {
  @service site;
  @service siteSettings;
  @computed
  get isCategoriesRoute() { return this.router.currentRouteName === "discovery.discussion-forums"; }
  get discussionCategory() { return this.site.categories.find(category => category.slug === "discussion"); }
  get directoryCategories() {
    const ids = [this.discussionCategory?.id, this.siteSettings.svdex_help_category_id, this.siteSettings.svdex_introductions_category_id, this.siteSettings.svdex_events_category_id].map(Number);
    return (this.model.content || []).filter(category => ids.includes(Number(category.id)));
  }
}
