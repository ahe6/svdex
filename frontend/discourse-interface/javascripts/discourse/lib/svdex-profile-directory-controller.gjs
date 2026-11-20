import { action } from "@ember/object";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
export default function profileDirectoryController(Base, fixedKind) {
  return class extends Base {
    request = 0;
    get independentProfiles() { return true; }
    async loadUsers(params = null) {
      const query = { ...(params || this.params || {}), kind: fixedKind || params?.kind || this.kind || "companies" };
      this.setProperties({ params: query, kind: query.kind, nameInput: query.name || "", order: query.order || (query.kind === "funds" ? "svdex_aum" : query.kind === "people" ? "username" : "svdex_total_funding"), isLoading: true });
      const request = ++this.request;
      try {
        const data = await ajax("/company-profiles.json", { data: query });
        if (request !== this.request) return;
        this.set("model", EmberObject.create({ content: this.entries(data), totalRows: data.total, canLoadMore: data.has_more, resultSetMeta: data }));
      } finally { if (request === this.request) this.set("isLoading", false); }
    }
    entries(data) { return data.profiles.map(entry => ({ ...entry, interestEndpoint: `/company-profile-interests/${entry.profile.id}` })); }
    @action async loadMore() {
      if (this.model.loadingMore || !this.model.canLoadMore) return;
      const model = this.model;
      model.set("loadingMore", true);
      try {
        const data = await ajax("/company-profiles.json", { data: { ...this.params, page: Math.floor(model.content.length / 25) } });
        if (model !== this.model) return;
        model.setProperties({ content: [...model.content, ...this.entries(data)], canLoadMore: data.has_more });
      } finally { model.set("loadingMore", false); }
    }
  };
}
