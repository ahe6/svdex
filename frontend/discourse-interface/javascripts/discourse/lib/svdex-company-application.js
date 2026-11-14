const clean = (value, limit) => String(value || "").trim().slice(0, limit);
const escape = value => value.replace(/[\\`*_{}[\]()#+.!>|-]/g, "\\$&").replace(/\r?\n/g, " ");
export function companyApplication(values = {}) {
  const fund = values.kind === "funds";
  const name = clean(values.name, 120);
  const representative = clean(values.representative, 120);
  const description = clean(values.description, 1200);
  const website = clean(values.website, 500);
  if (!name || !representative || !description || values.authorized !== true) return { error: fund ? "Complete the required fields and confirm that you are authorized to represent this fund." : "Complete the required fields and confirm that you are authorized to represent this company or project." };
  if (website) {
    try {
      const url = new URL(website);
      if (!["https:", "http:"].includes(url.protocol) || !url.hostname || url.username || url.password) throw new Error();
    } catch { return { error: "Enter a complete website address starting with https:// or http://, or leave it blank." }; }
  }
  return { reason: [fund ? "SVDEX fund application · v1" : "SVDEX company application · v1", "", `**${fund ? "Fund" : "Company or project"}:** ${escape(name)}`, `**Authorized representative:** ${escape(representative)}`, `**Description:** ${escape(description)}`, `**Website:** ${website ? escape(website) : "Not provided"}`, "**Authority confirmed:** Yes", "", "Staff review required. This application does not grant investor access or accreditation."].join("\n") };
}
