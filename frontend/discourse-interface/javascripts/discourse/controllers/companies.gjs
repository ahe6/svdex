import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { COMPANY_FILTER_KEYS, sectorLabel } from "../lib/svdex-company-filters";
import UsersController from "discourse/controllers/users";

export default class CompaniesController extends UsersController {
  @tracked kind = "companies";
  @tracked svdex_sector = null;
  @tracked svdex_funding = null;
  @tracked svdex_valuation = null;
  @tracked svdex_stage = null;
  @tracked svdex_location = null;
  @tracked svdex_open = null;
  @tracked svdex_type = null;
  @tracked svdex_aum = null;
  @tracked svdex_buy_interest = null;
  @tracked svdex_sell_interest = null;
  get isFund() { return this.kind === "funds"; }
  queryParams = ["kind","period", "order", "asc", "name", "group", "exclude_usernames", "exclude_groups", ...COMPANY_FILTER_KEYS];
  get emptyMessage() {
    const noun = this.kind === "funds" ? "funds" : this.kind === "all" ? "listings" : "companies";
    return this.hasCompanyFilters ? `No ${noun} match these filters.` : this.name ? `No ${noun} match your search.` : `No ${noun} to show.`;
  }
  get searchLabel() { return this.searchTitle; }
  get searchTitle() { return this.kind === "funds" ? "Search funds" : this.kind === "all" ? "Search listings" : "Search companies"; }
  get countKey() { return this.kind === "funds" ? "svdex.company.fund_rows" : this.kind === "all" ? "svdex.company.listing_rows" : "svdex.company.total_rows"; }
  get identityKey() { return this.kind === "funds" ? "svdex.company.fund" : this.kind === "all" ? "svdex.company.name" : "svdex.company.company"; }
  @action changeKind(kind) { this.set("kind", kind); }
  get showGroupFilter() { return false; }
  get sectors() { return (this.model?.get?.("resultSetMeta.sectors") || []).map(tag => ({ ...tag, name: sectorLabel(tag.name) })); }
  get stages() { return (this.model?.get?.("resultSetMeta.stages") || []).map(name => ({ id: name, name })).concat({ id: "undisclosed", name: "Undisclosed" }); }
  get locations() { return (this.model?.get?.("resultSetMeta.locations") || []).map(name => ({ id: name, name })).concat({ id: "undisclosed", name: "Undisclosed" }); }
  get hasDirectoryFilters() { return Boolean(this.name) || this.hasCompanyFilters; }
  get resetDirectoryLabel() { return this.name ? (this.hasCompanyFilters ? "Clear search and filters" : "Clear search") : "Clear filters"; }
  @action resetDirectoryFilters() {
    this.clearCompanyFilters();
    this.onUsernameFilterChanged("");
  }
  get hasCompanyFilters() { return COMPANY_FILTER_KEYS.some(key => Boolean(this[key])); }
  @action changeCompanyFilter(key, value) {
    if (COMPANY_FILTER_KEYS.includes(key)) this.set(key, value || null);
  }
  @action refreshInterest() { return this.loadUsers(); }
  loadGroups() { return Promise.resolve(); }
  loadUsers(params = null) {
    const query = params || this.params || {};
    query.svdex_company_directory = true;
    return super.loadUsers(query);
  }
  @action applyCompanyFilters(values) {
    this.setProperties(Object.fromEntries(COMPANY_FILTER_KEYS.map(key => [key, values[key] || null])));
  }
  @action clearCompanyFilters() { this.applyCompanyFilters({}); }
}
