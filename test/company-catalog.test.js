import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
const document = JSON.parse(readFileSync(new URL("../directory/companies/svdex.json", import.meta.url)));
function validate(texts) {
  const ruby = `require File.expand_path('./deploy/discourse/plugins/discourse-svdex/lib/discourse_svdex/prototypes/catalog_document'); puts JSON.generate(JSON.parse(STDIN.read).map { |text| begin; doc = DiscourseSvdex::Prototypes::CatalogDocument.parse(text); {valid: true, revision: DiscourseSvdex::Prototypes::CatalogDocument.revision(doc)}; rescue DiscourseSvdex::Prototypes::CatalogDocument::Invalid; {valid: false}; end })`;
  const result = spawnSync("ruby", ["-e", ruby], { input: JSON.stringify(texts), encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}
test("public company files reject private/account fields and ambiguous or unsupported financial data", () => {
  const financial = changes => ({ ...document, financials: { ...document.financials, ...changes } });
  const invalid = [
    { ...document, official_account_id: 5 }, { ...document, schema_version: 2 }, { ...document, id: "../users" },
    financial({ total_funding_usd: "2000000" }), financial({ total_funding_usd: -1 }),
    financial({ total_funding_usd: 100 }), financial({ total_funding_usd: 100, as_of: "2026-02-30", source_url: "https://example.com" }),
    financial({ total_funding_usd: 100, as_of: "2026-11-19", source_url: "javascript:alert(1)" }),
    { ...document, sources: [] }, { ...document, name: "" },
  ];
  assert.deepEqual(validate(invalid.map(value => JSON.stringify(value))).map(value => value.valid), invalid.map(() => false));
  assert.equal(validate(['{"schema_version":1,"schema_version":2}'])[0].valid, false);
});
test("company revisions ignore formatting/key order; sourced zero is valid and differs from unknown", () => {
  const zero = { ...document, financials: { ...document.financials, total_funding_usd: 0, as_of: "2026-11-19", source_url: "https://svdex.com" } };
  const results = validate([JSON.stringify(document), JSON.stringify(Object.fromEntries(Object.entries(document).reverse()), null, 2), JSON.stringify(zero)]);
  assert.ok(results.every(value => value.valid));
  assert.equal(results[0].revision, results[1].revision);
  assert.notEqual(results[0].revision, results[2].revision);
});
