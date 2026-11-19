export default function () {
  if (typeof window !== "undefined" && window.location.hostname === "localhost" && window.location.port === "4080") {
    this.route("independent-company", { path: "/company/:slug" });
  }
  this.route("companies", { path: "/companies" });
  this.route("people", { path: "/people" });
}
