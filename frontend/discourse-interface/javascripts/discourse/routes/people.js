import UsersRoute from "discourse/routes/users";

export default class PeopleRoute extends UsersRoute {
  queryParams = { ...this.queryParams, svdex_organization: { refreshModel: true }, svdex_location: { refreshModel: true } };
  resetController(controller, exiting) {
    super.resetController(...arguments);
    if (exiting) controller.clearFilters();
  }
  titleToken() { return "People"; }
  model(params) {
    return { params: { ...params, period: "all", group: this.siteSettings.svdex_people_group_name,
      order: "username", asc: params.asc }, columns: [] };
  }
}
