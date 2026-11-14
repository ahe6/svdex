import { formatFinancialAmount } from "./svdex-financial-format";
import { sectorLabel } from "./svdex-company-filters";
export function fundLife(company) {
  const start = Number(company.vintage_year);
  const term = company.fund_life?.trim();
  const years = term?.match(/^(\d{1,2})[- ]year(?: term)?$/i);
  if (start && years) return `${start}–${start + Number(years[1])}`;
  if (term && /^\d{4}\s*[–—-]\s*\d{4}$/.test(term)) return term.replace(/\s*[–—-]\s*/, "–");
  return [start || null, term].filter(Boolean).join(" · ") || "—";
}

export function directoryColumns(kind, includeInterest = true) {
  const columns = kind === "funds" ? [
    { key: "strategy", label: "Strategy" },
    { key: "people", label: "Key People" },
    { key: "aum", label: "AUM", filter: "svdex_aum" },
    { key: "fund_life", label: "Fund Life" },
    { key: "location", label: "Location", filter: "svdex_location" },
    { key: "open", label: "Open offerings", filter: "svdex_open" },
  ] : [
    { key: "sector", label: "Sector", filter: "svdex_sector" },
    { key: "people", label: "Key People" },
    { key: "valuation", label: "Last valuation", filter: "svdex_valuation" },
    { key: "funding", label: "Total funding", filter: "svdex_funding" },
    { key: "location", label: "Location", filter: "svdex_location" },
    { key: "open", label: "Open offerings", filter: "svdex_open" },
  ];
  if (includeInterest) columns.splice(3, 0, { key: "buy_interest", label: "Buy interest", filter: "svdex_buy_interest", sort: "svdex_buy_interest" }, { key: "sell_interest", label: "Sell interest", filter: "svdex_sell_interest", sort: "svdex_sell_interest" });
  return columns;
}
export function directoryFacts(company = {}, kind) {
  const amount = value => value == null ? "—" : formatFinancialAmount(`$${value}`);
  return directoryColumns(kind || company.kind).map(column => {
    const values = {
      buy_interest: amount(company.interest_totals?.buy == null ? null : company.interest_totals.buy / 100),
      sell_interest: amount(company.interest_totals?.sell == null ? null : company.interest_totals.sell / 100),
      sector: company.sector ? sectorLabel(company.sector.name) : "—",
      valuation: amount(company.last_valuation_usd), funding: amount(company.total_funding_usd),
      location: company.headquarters_country || "—", strategy: company.strategy_focus || "—",
      aum: amount(company.aum_usd),
      fund_life: fundLife(company),
      open: company.open_offerings ?? 0,
    };
    return { ...column, value: values[column.key], people: column.key === "people",
      url: column.key === "sector" ? company.sector?.url : column.key === "open" && company.open_offerings > 0 ? company.open_offerings_url : null };
  });
}
