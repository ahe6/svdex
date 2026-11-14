// Preserve Overview's established colors, independent of counts or sort order.
const colorOrder = [
  "finance", "hardware", "northstar", "svdex", "agriculture", "ai", "biotech",
  "climate", "consumer", "education", "energy", "healthcare", "industrials",
  "media", "property", "software", "transport", "community", "research",
  "financials", "founder-updates", "feedback", "notifications",
];

export function tagColor(name, palette) {
  const colors = (palette || "").split("|").filter(color => /^[0-9a-f]{6}$/i.test(color));
  if (!colors.length) return "0088CC";
  const normalized = String(name).toLowerCase();
  let index = colorOrder.indexOf(normalized);
  // Future tags get a stable color without fetching a public tag directory or
  // exposing private tags. Adding or editing other tags never changes this one.
  if (index < 0) {
    index = 0;
    for (const char of normalized) index = (index * 31 + char.codePointAt(0)) >>> 0;
  }
  return colors[index % colors.length];
}
