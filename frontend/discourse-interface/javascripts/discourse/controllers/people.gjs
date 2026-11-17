import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import UsersController from "discourse/controllers/users";

export default class PeopleController extends UsersController {
  period = "all";
  @tracked svdex_organization = null;
  @tracked svdex_location = null;
  queryParams = ["period", "order", "asc", "name", "group", "exclude_usernames", "exclude_groups", "svdex_organization", "svdex_location"];
  get hasPeopleFilters() { return Boolean(this.svdex_organization || this.svdex_location); }
  get organizations() { return this.model?.get?.("resultSetMeta.organizations") || []; }
  get locations() { return (this.model?.get?.("resultSetMeta.locations") || []).map(name => ({ id: name, name })); }
  @action changeFilter(key, value) {
    if (["svdex_organization", "svdex_location"].includes(key)) this.set(key, value || null);
  }
  @action clearFilters() { this.setProperties({ svdex_organization: null, svdex_location: null }); }

  get peopleCount() {
    const count = this.model?.totalRows || 0;
    return `${count} ${count === 1 ? "person" : "people"}`;
  }
  loadGroups() {}
  loadUsers(params) {
    return super.loadUsers({ ...(params || this.params), svdex_people_directory: true, period: "all", group: this.siteSettings.svdex_people_group_name });
  }
}
