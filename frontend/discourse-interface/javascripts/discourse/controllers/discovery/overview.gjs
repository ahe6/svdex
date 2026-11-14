import { service } from "@ember/service";
import { computed } from "@ember/object";
import CategoriesController from "discourse/controllers/discovery/categories";

export default class OverviewController extends CategoriesController {
  @service site;
  @service siteSettings;
  @computed
  get isCategoriesRoute() { return this.router.currentRouteName === "discovery.overview"; }
  get directoryCategories() {
    const rows = [...(this.model.content || [])];
    return rows;
  }
}
