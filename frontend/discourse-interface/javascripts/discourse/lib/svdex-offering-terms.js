import { presaleTerms } from "./svdex-presales.js";
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
    const instrumentLabels = { equity: "Equity", safe: "SAFE", convertible_note: "Convertible note", debt: "Debt", warrant: "Warrant", other: "" };
    secondary = data?.instrument_type && Object.hasOwn(instrumentLabels, data.instrument_type)
      ? data?.terms?.trim() || instrumentLabels[data.instrument_type]
      : /\bSAFE\b/i.test(title) ? "SAFE" : /^secondary\b/i.test(data?.summary || "") ? "Secondary" : data?.terms?.trim() || "";
  }
  return { primary, secondary, progress, missing: !primaryKey };
}

const EXEMPTION_LABELS = new Map([["506b", "506(b)"], ["506c", "506(c)"], ["4a7", "4(a)(7)"]]);

export function offeringExemption(topic) {
  const labels = new Set((topic?.tags || []).map(tag => EXEMPTION_LABELS.get(typeof tag === "string" ? tag : tag.name)).filter(Boolean));
  return labels.size === 1 ? labels.values().next().value : null;
}

export function topicTermsPreview(topic, { includeExemption = false } = {}) {
  let terms;
  if (topic.svdex_presale) terms = presaleTerms(topic.svdex_presale);
  else if (topic.svdex_listing) terms = offeringTerms(topic.svdex_listing, topic.title);
  if (!terms) return "";
  const exemption = includeExemption && topic.svdex_listing ? offeringExemption(topic) : null;
  return [terms.primary, terms.secondary, exemption].filter(Boolean).join(" · ");
}
