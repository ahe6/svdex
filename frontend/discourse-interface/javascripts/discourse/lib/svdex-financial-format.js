const numberFormat = new Intl.NumberFormat("en-US", { maximumFractionDigits: 1 });
const fullNumberFormat = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });
const scales = [1_000, 1_000_000, 1_000_000_000];
const suffixes = ["K", "M", "B"];

// Only compact an unambiguous amount. Preserve currencies, ranges and authored
// qualifications rather than guessing what free-form listing text means.
export function formatFinancialAmount(value) {
  const text = String(value ?? "").trim();
  if (!text) return "—";
  const match = text.match(/^(?:([A-Z]{3}|[$€£])\s*)?(-?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?)\s*([A-Z]{3})?$/);
  if (!match || (match[1] && match[3])) return text;
  const amount = Number(match[2].replaceAll(",", ""));
  if (!Number.isFinite(amount) || Math.abs(amount) > Number.MAX_SAFE_INTEGER || Math.abs(amount) < 1_000) return text;
  let index = Math.abs(amount) >= scales[2] ? 2 : Math.abs(amount) >= scales[1] ? 1 : 0;
  if (index < 2 && Math.round(Math.abs(amount / scales[index]) * 10) / 10 >= 1_000) index++;
  const compact = `${numberFormat.format(amount / scales[index])}${suffixes[index]}`;
  const currency = match[1] || match[3];
  return currency ? `${currency}${/^[$€£]$/.test(currency) ? "" : " "}${compact}` : compact;
}

export function formatValuation(value, compact = false) {
  const amount = Number(value);
  if (!value || !Number.isSafeInteger(amount) || amount <= 0) return "—";
  const full = `USD ${fullNumberFormat.format(amount)}`;
  return compact ? formatFinancialAmount(full) : full;
}

// Organization facts are integer USD; interest totals are integer cents. Keep
// their units explicit, and do not turn blank/invalid facts into a measured zero.
// Build cents text with integer arithmetic before display-only compaction.
export function formatUsdAmount(value, { cents = false } = {}) {
  if (typeof value !== "number" && !(typeof value === "string" && /^(0|[1-9]\d*)$/.test(value))) return "—";
  const amount = Number(value);
  if (!Number.isSafeInteger(amount) || amount < 0) return "—";
  let text = String(amount);
  if (cents) {
    const fraction = String(amount % 100).padStart(2, "0").replace(/0+$/, "");
    text = `${Math.floor(amount / 100)}${fraction ? `.${fraction}` : ""}`;
  }
  return formatFinancialAmount(`$${text}`);
}
