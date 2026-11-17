import test from 'node:test';
import assert from 'node:assert/strict';
import { presaleTerms, isPresaleCategory } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-presales.js';

test('product terms describe purchases without interpreting them as securities', () => {
  assert.deepEqual(presaleTerms({ price: '$120 per year', includes: '12 months of tools', delivery: 'January 2027', valuation_cap: '10000000', interest_rate: '8%', funds_raised: '100' }), {
    primary: '$120 per year', secondary: '12 months of tools · January 2027', progress: null, missing: false,
  });
  assert.equal(presaleTerms({ includes: 'Device', price: '  ' }).primary, 'Price not set');
  assert.equal(presaleTerms({ price: '$249 per device', delivery: 'March 2027' }).secondary, 'March 2027');
  assert.equal(isPresaleCategory(0, { svdex_presales_category_id: 0 }), false);
  assert.equal(isPresaleCategory('12', { svdex_presales_category_id: 12 }), true);
});
