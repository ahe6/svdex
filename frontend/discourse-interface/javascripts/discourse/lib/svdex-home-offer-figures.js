import { instrumentData } from "./svdex-offering-instruments.js";
import { formatFinancialAmount, formatValuation } from "./svdex-financial-format.js";

export function listingFigures(data) {
  data = instrumentData(data);
  if (!data) return [];
  return [
    { key: "valuation", label: "Valuation", value: formatValuation(data.post_money_valuation_usd, true) },
    { key: "total_funding", label: "Total funding", value: data.total_funding && formatFinancialAmount(data.total_funding) },
    { key: "offering_size", label: "Target", value: data.offering_size && formatFinancialAmount(data.offering_size) },
    { key: "minimum", label: "Minimum", value: data.minimum && formatFinancialAmount(data.minimum) },
    { key: "interest_rate", label: "Interest rate", value: data.interest_rate },
    { key: "valuation_cap", label: "Cap", value: data.valuation_cap && formatFinancialAmount(data.valuation_cap) },
    { key: "conversion_discount", label: "Discount", value: data.conversion_discount },
    { key: "strike_price", label: "Strike", value: data.strike_price && formatFinancialAmount(data.strike_price) },
    { key: "expiration", label: "Expiry", value: data.expiration },
    { key: "terms", label: "Terms", value: data.terms },
  ].filter(item => item.value?.trim() && !["—", "-"].includes(item.value.trim()));
}

export function homeOfferFigures(data, { maxTerms = 2, includeOfferingAmounts = false } = {}) {
  const fields = new Map(listingFigures(data).map(item => [item.key, item]));
  if (!data) return [];
  const funding = fields.get("total_funding") || { key: "total_funding", label: "Total funding", value: "—" };
  let keys;
  if (fields.has("valuation_cap") || fields.has("conversion_discount")) {
    keys = ["valuation_cap", "conversion_discount", "interest_rate"];
  } else if (fields.has("strike_price")) {
    keys = ["strike_price", "expiration"];
  } else if (fields.has("valuation")) {
    keys = ["valuation", "interest_rate"];
  } else {
    keys = ["interest_rate", "expiration"];
  }
  if (includeOfferingAmounts) keys.push("offering_size", "minimum");
  const terms = keys.map(key => fields.get(key)).filter(Boolean).slice(0, maxTerms).map(term => {
    if (term.key !== "interest_rate") return term;
    const annual = term.value.trim().match(/^(.+?%)\s+(?:annually|per year|per annum|p\.a\.)$/i);
    return { ...term, label: "Rate", value: annual ? `${annual[1]} / yr` : term.value };
  });
  return [funding, ...terms];
}

export function secondaryOfferFigures(data) {
  const primaryKeys = new Set(homeOfferFigures(data).map(item => item.key));
  return listingFigures(data).filter(item => !primaryKeys.has(item.key));
}

// Compact feed facts retain the meaning even without a separate column label.
export function compactOfferFact({ key, label, value }) {
  const amount = value.replace(/^USD\s+/, "$");
  if (key === "interest_rate") return amount.replace(/\s*\/\s*(?:yr|year)\b/gi, "/yr").replace(/^(.*?%)\s+(?:annually|per year|per annum|p\.a\.)$/i, "$1/yr");
  const suffixes = {
    total_funding: "total funding", valuation: "valuation", offering_size: "target",
    minimum: "min", valuation_cap: "cap", conversion_discount: "discount",
    strike_price: "strike",
  };
  if (key === "expiration") return `expires ${amount}`;
  return `${amount} ${suffixes[key] || label.toLowerCase()}`;
}
