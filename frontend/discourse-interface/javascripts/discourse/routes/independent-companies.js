import CompaniesRoute from "./companies";
export default class IndependentCompaniesRoute extends CompaniesRoute {
  beforeModel() {} // Published company facts do not depend on account visibility.
  model(params) { return { params: { ...params, kind: "companies", order: ["username", "svdex_total_funding", "svdex_last_valuation", "svdex_buy_interest", "svdex_sell_interest"].includes(params.order) ? params.order : "svdex_total_funding" }, columns: [] }; }
  titleToken() { return "Companies"; }
}
