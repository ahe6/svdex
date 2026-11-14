import assert from "node:assert/strict";
import test from "node:test";
import { homeOfferFigures, secondaryOfferFigures, listingFigures, compactOfferFact } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-home-offer-figures.js";

test("Home keeps funding fixed and separates instrument terms from supplementary figures", () => {
  const equity = { total_funding: "USD 2000000", post_money_valuation_usd: "10000000", offering_size: "USD 1000000", minimum: "USD 100" };
  assert.deepEqual(homeOfferFigures(equity).map(item => [item.label, item.value]), [["Total funding", "USD 2M"], ["Valuation", "USD 10M"]]);
  assert.deepEqual(secondaryOfferFigures(equity).map(item => item.key), ["offering_size", "minimum"]);
  const note = { total_funding: "USD 2000000", valuation_cap: "USD 10000000", conversion_discount: "20%", interest_rate: "6% annually", terms: "24-month maturity" };
  assert.deepEqual(homeOfferFigures(note).map(item => item.label), ["Total funding", "Cap", "Discount"]);
  assert.deepEqual(secondaryOfferFigures(note).map(item => item.key), ["interest_rate", "terms"]);
  assert.equal(listingFigures(note).length, 5);
});

test("Home handles debt, warrants and missing disclosures without substituting offering targets for funding", () => {
  assert.deepEqual(homeOfferFigures({ interest_rate: "8%", offering_size: "USD 2000000" }).map(item => item.value), ["—", "8%"]);
  assert.deepEqual(homeOfferFigures({ interest_rate: "8% annually" })[1], { key: "interest_rate", label: "Rate", value: "8% / yr" });
  assert.deepEqual(homeOfferFigures({ strike_price: "USD 2.50", expiration: "2030-06-30" }).map(item => item.label), ["Total funding", "Strike", "Expiry"]);
  assert.deepEqual(homeOfferFigures({ offering_size: "USD 2000000", minimum: "USD 100" }).map(item => item.value), ["—"]);
  assert.deepEqual(secondaryOfferFigures({ terms: "Custom terms" }).map(item => item.value), ["Custom terms"]);
  assert.deepEqual(homeOfferFigures(), []);
});

test("Desktop caps offering figures at four without expanding mobile previews", () => {
  const data = { total_funding: "USD 2000000", valuation_cap: "USD 10000000", conversion_discount: "20%", interest_rate: "6% annually", offering_size: "USD 1000000", minimum: "USD 100" };
  const desktop = { maxTerms: 3, includeOfferingAmounts: true };
  assert.deepEqual(homeOfferFigures(data, desktop).map(item => item.label), ["Total funding", "Cap", "Discount", "Rate"]);
  assert.equal(homeOfferFigures(data).length, 3);
  assert.deepEqual(homeOfferFigures({ total_funding: "USD 12000000", interest_rate: "8% annually", offering_size: "USD 3000000", minimum: "USD 1000" }, desktop).map(item => item.label), ["Total funding", "Rate", "Target", "Minimum"]);
});

test('compact offering text is self-describing without redundant labels', () => {
  const facts = homeOfferFigures({ total_funding: "USD 12000000", interest_rate: "8% annually", offering_size: "USD 2000000", minimum: "USD 100" }, { maxTerms: 3, includeOfferingAmounts: true });
  assert.equal(facts.map(compactOfferFact).join(" · "), "$12M total funding · 8%/yr · $2M target · $100 min");
  assert.equal(compactOfferFact({ key: "valuation_cap", label: "Cap", value: "USD 10M" }), "$10M cap");
  assert.equal(compactOfferFact({ key: "conversion_discount", label: "Discount", value: "20%" }), "20% discount");
  assert.equal(compactOfferFact({ key: "valuation", label: "Valuation", value: "EUR 20M" }), "EUR 20M valuation");
  assert.equal(compactOfferFact({ key: "expiration", label: "Expiry", value: "2030-06-30" }), "expires 2030-06-30");
});
