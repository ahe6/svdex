import PeopleRoute from "./people";
export default class IndependentPeopleRoute extends PeopleRoute {
  beforeModel() {}
  model(params) { return { params: { ...params, kind: "people", order: params.order || "username" }, columns: [] }; }
}
