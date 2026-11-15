import test from "node:test";
import assert from "node:assert/strict";
import { inferredInstrument, instrumentAllowsField, instrumentData } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-offering-instruments.js";
import { offeringTerms } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-offering-terms.js";
import { composerCategoryChoices, composerCategoryScope } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-offering-categories.js";

test("instrument fields distinguish equity, SAFE, notes, debt and warrants", () => {
  assert.equal(instrumentAllowsField("equity", "post_money_valuation_usd"), true);
  assert.equal(instrumentAllowsField("equity", "interest_rate"), false);
  assert.equal(instrumentAllowsField("safe", "valuation_cap"), true);
  assert.equal(instrumentAllowsField("safe", "interest_rate"), false);
  assert.equal(instrumentAllowsField("convertible_note", "interest_rate"), true);
  assert.equal(instrumentAllowsField("debt", "valuation_cap"), false);
  assert.equal(instrumentAllowsField("warrant", "strike_price"), true);
  assert.equal(instrumentAllowsField("warrant", "expiration"), true);
  assert.equal(instrumentAllowsField("other", "valuation_cap"), true);
  assert.equal(instrumentAllowsField("", "summary"), true);
});
test("saved instrument takes priority; legacy titles and terms still open sensibly", () => {
  assert.equal(inferredInstrument({instrument_type:"debt"}, "SAFE"), "debt");
  assert.equal(inferredInstrument({valuation_cap:"$10M",interest_rate:"6%"}, "Pre-seed SAFE"), "safe");
  assert.equal(inferredInstrument({valuation_cap:"$10M",interest_rate:"6%"}), "convertible_note");
  assert.equal(inferredInstrument({}, "2030 Bond"), "debt");
  assert.equal(inferredInstrument({}), "");
});
test("changing instrument preserves entries while displayed figures match the chosen type", () => {
  const data = {instrument_type:"debt",valuation_cap:"USD 10000000",post_money_valuation_usd:"20000000",interest_rate:"8% annually",offering_size:"USD 2000000"};
  assert.equal(offeringTerms(data).primary, "8%/yr");
  assert.equal(offeringTerms({instrument_type:"debt",interest_rate:"8% annually"}, "Old SAFE title").secondary, "Debt");
  assert.equal(data.valuation_cap, "USD 10000000");
  assert.equal(instrumentData(data).valuation_cap, undefined);
  assert.equal(instrumentData({...data,instrument_type:"safe"}).interest_rate, undefined);
  assert.equal(offeringTerms({...data,instrument_type:"safe"}).primary, "$10M cap");
  assert.equal(instrumentData({...data,instrument_type:"other"}).interest_rate, "8% annually");
});
test("composer categories stay in their originating scope without adding unauthorized categories", () => {
  const settings={svdex_listings_category_id:6,svdex_public_offerings_category_id:117,svdex_private_offerings_category_id:85};
  const authorized=[{id:6},{id:117},{id:85},{id:5},{id:47},{id:124}];
  assert.equal(composerCategoryScope(117,settings,5),"offerings");
  assert.equal(composerCategoryScope(5,settings,5),"community");
  for (const path of ["/", "/latest", "/top?period=monthly", "/all-forums"]) {
    assert.equal(composerCategoryScope(undefined,settings,5,path),"community");
    assert.equal(composerCategoryScope(117,settings,5,path),"community");
  }
  assert.equal(composerCategoryScope(117,settings,5,"/c/offerings/public-offerings/117"),"offerings");
  assert.deepEqual(composerCategoryChoices(authorized,"offerings",settings).map(c=>c.id),[117,85]);
  assert.deepEqual(composerCategoryChoices(authorized,"community",settings).map(c=>c.id),[5,47,124]);
  assert.deepEqual(composerCategoryChoices([{id:117},{id:5}],"offerings",settings).map(c=>c.id),[117]);
});
