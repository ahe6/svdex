import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
export default class IndependentPersonRoute extends DiscourseRoute {
  model({ slug }) { return ajax(`/person-profiles/${encodeURIComponent(slug)}.json`); }
  titleToken() { return this.currentModel?.profile.name || "Person"; }
}
