import test from 'node:test';
import assert from 'node:assert/strict';
import { offeringTerms } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-offering-terms.js';

test('desktop terms emphasize each instrument and keep secondary facts together', () => {
  assert.deepEqual(offeringTerms({ valuation_cap: 'USD 10000000', conversion_discount: '20%', interest_rate: '6% annually' }), { primary: '$10M cap', secondary: '20% discount · 6%/yr', progress: null, missing: false });
  assert.equal(offeringTerms({ interest_rate: '8% annually', offering_size: 'USD 2000000', minimum: 'USD 100' }).secondary, '$2M target · $100 min');
  assert.equal(offeringTerms({ valuation_cap: 'USD 10000000' }, 'SVDEX — SAFE').secondary, 'SAFE');
  assert.equal(offeringTerms({ summary: 'Secondary ordinary shares.' }).secondary, 'Secondary');
});

test('progress requires offering-specific, comparable amounts and handles zero and overfunding', () => {
  const data = { post_money_valuation_usd: '20000000', total_funding: 'USD 2000000', offering_size: 'USD 5000000' };
  assert.equal(offeringTerms(data).progress, null);
  assert.equal(offeringTerms(data).secondary, '$5M target');
  assert.deepEqual(offeringTerms({ ...data, funds_raised: 'USD 2000000' }), { primary: '$20M valuation', secondary: '$2M of $5M raised', progress: 40, missing: false });
  assert.equal(offeringTerms({ ...data, funds_raised: 'USD 0' }).progress, 0);
  assert.equal(offeringTerms({ ...data, funds_raised: 'USD 6000000' }).progress, 100);
  for (const funds_raised of ['EUR 2000000', 'USD 1M–2M', 'approximately $2M']) assert.equal(offeringTerms({ ...data, funds_raised }).progress, null);
});
