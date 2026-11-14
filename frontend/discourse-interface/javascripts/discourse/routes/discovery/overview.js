import CategoriesRoute from "discourse/routes/discovery/categories";

// Use the native category directory query and its visibility rules.
export default class OverviewRoute extends CategoriesRoute {
  templateName = "discovery/overview";
  controllerName = "discovery/overview";
  titleToken() { return "Overview"; }
}
