export default function () {
  if (typeof window !== "undefined" && window.location.hostname === "localhost" && window.location.port === "4080") {
    this.route("independent-companies", { path: "/company-directory" });
    this.route("independent-company", { path: "/company/:slug" });
    this.route("independent-funds", { path: "/fund-directory" });
    this.route("independent-fund", { path: "/fund/:slug" });
    this.route("independent-people", { path: "/person-directory" });
    this.route("independent-person", { path: "/person/:slug" });
  }
  this.route("companies", { path: "/companies" });
  this.route("people", { path: "/people" });
}
