import { action } from "@ember/object";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import CompaniesController from "./companies.gjs";
export default class IndependentCompaniesController extends CompaniesController {
  request = 0;
  async loadUsers(params = null) {
    const query = { ...(params || this.params || {}), kind: "companies" };
    this.setProperties({ params: query, nameInput: query.name || "", order: query.order || "svdex_total_funding", isLoading: true });
    const request = ++this.request;
    try {
      const data = await ajax("/company-profiles.json", { data: query });
      if (request !== this.request) return;
      this.set("model", EmberObject.create({ content: data.profiles.map(entry => ({ ...entry, interestEndpoint: `/company-profile-interests/${entry.profile.id}` })), totalRows: data.total, canLoadMore: data.has_more, resultSetMeta: data }));
    } finally { if (request === this.request) this.set("isLoading", false); }
  }
  @action async loadMore() {
    if (this.model.loadingMore || !this.model.canLoadMore) return;
    const model = this.model;
    model.set("loadingMore", true);
    try {
      const data = await ajax("/company-profiles.json", { data: { ...this.params, page: Math.floor(model.content.length / 25) } });
      if (model !== this.model) return;
      model.setProperties({ content: [...model.content, ...data.profiles.map(entry => ({ ...entry, interestEndpoint: `/company-profile-interests/${entry.profile.id}` }))], canLoadMore: data.has_more });
    } finally { model.set("loadingMore", false); }
  }
}
