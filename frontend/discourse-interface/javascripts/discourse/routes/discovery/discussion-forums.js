import CategoriesRoute from "discourse/routes/discovery/categories";

export default class DiscussionForumsRoute extends CategoriesRoute {
  templateName = "discovery/discussion-forums";
  controllerName = "discovery/discussion-forums";
  titleToken() { return "Overview"; }
}
