import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class InterestRoute extends DiscourseRoute {
  @service currentUser;
  queryParams = {};
  model() {
    if (!this.currentUser || this.modelFor("user").id !== this.currentUser.id) return { permissionDenied: true };
    return ajax("/listings/my-interest.json", { data: { kind: "all", status: "all" } });
  }
  setupController(controller, model) {
    super.setupController(...arguments);
    controller.setProperties({ kind: "all", status: "all", records: model.records || [], hasMore: Boolean(model.has_more), page: 0 });
  }
  titleToken() { return "Interest & bids"; }
}
