import CompaniesRoute from "./companies";
export default class IndependentFundsRoute extends CompaniesRoute {
  beforeModel() {}
  model(params) { return { params: { ...params, kind: "funds", order: ["username", "svdex_aum", "svdex_buy_interest", "svdex_sell_interest"].includes(params.order) ? params.order : "svdex_aum" }, columns: [] }; }
  titleToken() { return "Funds"; }
}
