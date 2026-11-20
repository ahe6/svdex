import { withPluginApi } from "discourse/lib/plugin-api";
import { addDiscoveryQueryParam } from "discourse/controllers/discovery/list";

export default {
  name: "svdex-company-search-query",
  before: "inject-discourse-objects",
  initialize() {
    withPluginApi(api => {
      if (api.container.lookup("service:site-settings").svdex_listings_category_id === undefined) return;
      ["svdex_company", "svdex_valuation", "svdex_active", "svdex_home", "svdex_view", "svdex_presales", "svdex_product_category", "svdex_product_stage", "svdex_product_asc"].forEach(key => addDiscoveryQueryParam(key, { replace: false, refreshModel: true }));
    });
  },
};
