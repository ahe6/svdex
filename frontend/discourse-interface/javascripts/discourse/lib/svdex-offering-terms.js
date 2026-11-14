import { compactOfferFact, listingFigures } from "./svdex-home-offer-figures.js";
import { formatFinancialAmount } from "./svdex-financial-format.js";

function amount(value) {
  const match = String(value ?? "").trim().match(/^(USD|EUR|GBP|[$€£])?\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*([KMB])?\s*(USD|EUR|GBP)?$/i);
  if (!match || (match[1] && match[4])) return null;
  const currencies = { $: "USD", "€": "EUR", "£": "GBP" };
  const currency = match[1] || match[4] || "";
  return {
    currency: currencies[currency] || currency.toUpperCase(),
    value: Number(match[2].replaceAll(",", "")) * ({ K: 1e3, M: 1e6, B: 1e9 }[match[3]?.toUpperCase()] || 1),
  };
}

// Dedicated desktop terms and compact mobile previews share instrument-first content.
// Offering progress never uses company-wide total funding as its numerator.
export function offeringTerms(data, title = "") {
  const facts = new Map(listingFigures(data).map(fact => [fact.key, fact]));
  const primaryKey = ["valuation_cap", "strike_price", "valuation", "interest_rate", "conversion_discount"].find(key => facts.has(key));
  const primary = primaryKey ? compactOfferFact(facts.get(primaryKey)) : "Price not set";
  const secondaryKeys = primaryKey === "valuation_cap" ? ["conversion_discount", "interest_rate"] : primaryKey === "strike_price" ? ["expiration"] : ["interest_rate", "offering_size", "minimum"];
  let secondary = secondaryKeys.filter(key => key !== primaryKey && facts.has(key)).slice(0, 2).map(key => compactOfferFact(facts.get(key))).join(" · ");
  let progress = null;
  const raised = amount(data?.funds_raised);
  const target = amount(data?.offering_size);
  if (primaryKey === "valuation" && raised && target && raised.currency === target.currency && target.value > 0 && Number.isFinite(raised.value) && Number.isFinite(target.value)) {
    const display = value => formatFinancialAmount(value).replace(/^USD\s+/, "$");
    secondary = `${display(data.funds_raised)} of ${display(data.offering_size)} raised`;
    progress = Math.min(100, Math.max(0, raised.value / target.value * 100));
  }
  if (!secondary) {
    secondary = /\bSAFE\b/i.test(title) ? "SAFE" : /^secondary\b/i.test(data?.summary || "") ? "Secondary" : data?.terms?.trim() || "";
  }
  return { primary, secondary, progress, missing: !primaryKey };
}
