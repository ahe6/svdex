import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
// The same transformation is used by both the table and profile view.
let source = readFileSync(new URL('../frontend/discourse-interface/javascripts/discourse/lib/svdex-directory-columns.js', import.meta.url), 'utf8');
const base = new URL('../frontend/discourse-interface/javascripts/discourse/lib/', import.meta.url);
source = source.replace('"./svdex-financial-format"', JSON.stringify(new URL('svdex-financial-format.js', base).href)).replace('"./svdex-company-filters"', JSON.stringify(new URL('svdex-company-filters.js', base).href));
const {directoryColumns, directoryFacts, fundLife} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
test('company and fund facts stay distinct with eight directory columns apiece', () => {
 assert.equal(directoryColumns('companies').length, 8);
 assert.equal(directoryColumns('funds').length, 8);
 assert.equal(directoryColumns('companies')[2].label, 'Last valuation');
 assert.equal(directoryColumns('funds')[2].label, 'AUM');
 assert.equal(directoryColumns('funds')[3].key, 'buy_interest');
 const facts = directoryFacts({kind:'funds',aum_usd:12500000,fund_size_usd:50000000,fund_size_basis:'target',vintage_year:2024,total_funding_usd:9000000});
 assert.equal(facts.find(x=>x.key==='aum').value, '$12.5M');
 assert.equal(facts.find(x=>x.key==='fund_life').value, '2024');
 assert.ok(!facts.some(x=>x.key==='funding'));
 assert.equal(directoryFacts({kind:'funds',fund_size_usd:50000000,fund_size_basis:'target'}).find(x=>x.key==='aum').value, '—');
});
test('unknown money stays missing while zero active offerings remains a count', () => {
 const facts = directoryFacts({open_offerings:0,open_offerings_url:'/private'});
 assert.equal(facts.find(x=>x.key==='valuation').value, '—');
 assert.equal(facts.find(x=>x.key==='open').value, 0);
 assert.equal(facts.find(x=>x.key==='open').url, null);
});

test('staff interest preview distinguishes unmeasured amounts from measured zero', () => {
 const publicFacts = directoryFacts({});
 assert.equal(publicFacts.length, 8);
 assert.equal(publicFacts.find(x => x.key === 'buy_interest').value, '—');
 assert.equal(publicFacts.find(x => x.key === 'sell_interest').value, '—');
 const privateFacts = directoryFacts({interest_totals: {buy: 0, sell: 12500000}});
 assert.equal(privateFacts.length, 8);
 assert.equal(privateFacts.find(x => x.key === 'buy_interest').value, '$0');
 assert.equal(privateFacts.find(x => x.key === 'sell_interest').value, '$125K');
 const unmeasured = directoryFacts({interest_totals: {}});
 assert.equal(unmeasured.find(x => x.key === 'buy_interest').value, '—');
});

test('fund life uses a year range only for an explicit simple term', () => {
 assert.equal(fundLife({vintage_year:2016,fund_life:'10-year term'}), '2016–2026');
 assert.equal(fundLife({vintage_year:2026,fund_life:'Evergreen'}), '2026 · Evergreen');
 assert.equal(fundLife({vintage_year:2024}), '2024');
 assert.equal(fundLife({fund_life:'2016 - 2026'}), '2016–2026');
 assert.equal(fundLife({fund_life:'10-year term'}), '10-year term');
});
