export const COMPANY_FILTER_KEYS = ["svdex_sector", "svdex_funding", "svdex_valuation", "svdex_stage", "svdex_location", "svdex_open", "svdex_type", "svdex_aum", "svdex_buy_interest", "svdex_sell_interest"];
export const MONEY_RANGES = [
  { id: "under_1m", name: "Under $1M" }, { id: "1m_10m", name: "$1M–$10M" },
  { id: "10m_100m", name: "$10M–$100M" }, { id: "100m_1b", name: "$100M–$1B" },
  { id: "over_1b", name: "$1B or more" }, { id: "undisclosed", name: "Undisclosed" },
];
export const OPEN_OFFERING_OPTIONS = [{ id: "yes", name: "Yes" }, { id: "no", name: "No" }];
export function companyFilterOptions(controller, field) {
  switch (field) {
    case "svdex_type": return { reset: "All entity types", options: [{id:"company", name:"Company"}, {id:"spv", name:"SPV"}] };
    case "svdex_sector": return { reset: "All sectors", options: controller.sectors };
    case "svdex_stage": return { reset: "All stages", options: controller.stages };
    case "svdex_location": return { reset: "All locations", options: controller.locations };
    case "svdex_open": return { reset: "Any", options: OPEN_OFFERING_OPTIONS };
    default: return { reset: "Any value", options: MONEY_RANGES };
  }
}

export function sectorLabel(name) {
  return name.toLowerCase() === "ai" ? "AI" : name.charAt(0).toLocaleUpperCase() + name.slice(1);
}
