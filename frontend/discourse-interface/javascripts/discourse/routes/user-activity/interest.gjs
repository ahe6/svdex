import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class InterestRoute extends DiscourseRoute {
  @service currentUser;
  queryParams = { kind: { refreshModel: true }, status: { refreshModel: true } };
  model(params) {
    if (!this.currentUser || this.modelFor("user").id !== this.currentUser.id) return { permissionDenied: true };
    return ajax("/listings/my-interest.json", { data: { kind: params.kind, status: params.status } });
  }
  setupController(controller, model) {
    super.setupController(...arguments);
    controller.setProperties({ records: model.records || [], hasMore: Boolean(model.has_more), page: 0 });
  }
  titleToken() { return "Interest & bids"; }
}
