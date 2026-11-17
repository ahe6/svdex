import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
export default class DiscoveriesController extends Controller {
  queryParams = ["page"];
  @tracked page = 0;
  @action next() { this.page++; }
  @action previous() { this.page = Math.max(0, this.page - 1); }
  get countLabel() { return `${this.model.count} ${this.model.count === 1 ? "discovery" : "discoveries"}`; }
  get hasPrevious() { return this.page > 0; }
}
