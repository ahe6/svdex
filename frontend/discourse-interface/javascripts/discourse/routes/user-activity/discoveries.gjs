import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
export default class DiscoveriesRoute extends DiscourseRoute {
  queryParams = { page: { refreshModel: true } };
  model(params) { return ajax(`/listings/discoveries/${encodeURIComponent(this.modelFor("user").username)}.json`, { data: { page: params.page } }); }
  titleToken() { return "Discoveries"; }
}
