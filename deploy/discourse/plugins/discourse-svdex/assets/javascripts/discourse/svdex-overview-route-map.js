export default {
  resource: "discovery",
  path: "/",
  map() {
    this.route("overview", { path: "/all-forums" });
    this.route("discussion-forums", { path: "/discussion-forums" });
  },
};
