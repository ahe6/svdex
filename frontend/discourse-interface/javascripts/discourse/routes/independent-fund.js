import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
export default class IndependentFundRoute extends DiscourseRoute {
  model({ slug }) { return ajax(`/fund-profiles/${encodeURIComponent(slug)}.json`); }
  titleToken() { return this.currentModel?.profile.name || "Fund"; }
}
