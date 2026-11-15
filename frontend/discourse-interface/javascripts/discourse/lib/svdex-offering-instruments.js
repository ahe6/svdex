export const INSTRUMENTS = [
  { id: "equity", name: "Equity" }, { id: "safe", name: "SAFE" },
  { id: "convertible_note", name: "Convertible note" }, { id: "debt", name: "Debt / bond" },
  { id: "warrant", name: "Warrant" }, { id: "other", name: "Other" },
];
const SPECIFIC = {
  equity: ["post_money_valuation_usd"], safe: ["valuation_cap", "conversion_discount"],
  convertible_note: ["valuation_cap", "conversion_discount", "interest_rate"], debt: ["interest_rate"],
  warrant: ["strike_price", "expiration"],
};
const SPECIFIC_FIELDS = new Set(Object.values(SPECIFIC).flat());
export function inferredInstrument(data = {}, title = "") {
  if (INSTRUMENTS.some(type => type.id === data.instrument_type)) return data.instrument_type;
  if (/\bwarrants?\b/i.test(title)) return "warrant";
  if (/\bconvertible\s+note\b/i.test(title)) return "convertible_note";
  if (/\bSAFE\b/i.test(title)) return "safe";
  if (/\b(bond|debt|loan)\b/i.test(title)) return "debt";
  if (/\b(shares?|equity|preferred)\b/i.test(title)) return "equity";
  if (data.strike_price || data.expiration) return "warrant";
  if (data.valuation_cap && data.interest_rate) return "convertible_note";
  if (data.valuation_cap) return "safe";
  if (data.post_money_valuation_usd) return "equity";
  if (data.interest_rate) return "debt";
  // Unclassified older offerings retain all of their existing fields.
  return Object.keys(data).some(key => SPECIFIC_FIELDS.has(key) && data[key]) ? "other" : "";
}
export function instrumentAllowsField(instrument, key) {
  return !SPECIFIC_FIELDS.has(key) || instrument === "other" || (SPECIFIC[instrument] || []).includes(key);
}
export function instrumentData(data) {
  if (!data?.instrument_type || !INSTRUMENTS.some(type => type.id === data.instrument_type)) return data;
  return Object.fromEntries(Object.entries(data).filter(([key]) => instrumentAllowsField(data.instrument_type, key)));
}
