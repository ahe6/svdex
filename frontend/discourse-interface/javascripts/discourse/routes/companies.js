import { COMPANY_FILTER_KEYS } from "../lib/svdex-company-filters";
import UsersRoute from "discourse/routes/users";

export default class CompaniesRoute extends UsersRoute {
  queryParams = { ...this.queryParams, kind: { refreshModel: true }, ...Object.fromEntries(COMPANY_FILTER_KEYS.map(key => [key, { refreshModel: true }])) };
  resetController(controller, exiting) {
    super.resetController(...arguments);
    if (exiting) {
      controller.set("kind", "companies");
      controller.clearCompanyFilters();
    }
  }
  titleToken() { return "Companies & Funds"; }
  async model(params) {
    return super.model({ ...params,
      group: this.siteSettings.svdex_companies_group_name,
      order: ["username", "svdex_total_funding", "svdex_last_valuation", "svdex_aum", "svdex_buy_interest", "svdex_sell_interest"].includes(params.order) ? params.order : params.kind === "funds" ? "svdex_aum" : "svdex_total_funding",
    });
  }
}
