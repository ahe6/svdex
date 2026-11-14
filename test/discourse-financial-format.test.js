import test from 'node:test';
import assert from 'node:assert/strict';
import { formatFinancialAmount, formatValuation } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-financial-format.js';

test('listing amounts compact thousands, millions and billions without losing currency', () => {
  for (const [input, expected] of [
    ['USD 2,000,000', 'USD 2M'], ['$1500000000', '$1.5B'], ['2500 EUR', 'EUR 2.5K'],
    ['£1000', '£1K'], ['USD 999,999', 'USD 1M'], ['999950000', '1B'], ['USD 100', 'USD 100'],
  ]) assert.equal(formatFinancialAmount(input), expected);
  assert.equal(formatValuation('50000000', true), 'USD 50M');
  assert.equal(formatValuation('50000000'), 'USD 50,000,000');
});

test('listing formatting preserves qualified or ambiguous text and leaves missing values undisclosed', () => {
  for (const input of ['Up to USD 2,000,000', 'USD 1,000–5,000', '2,5', 'USD 2M', '8% annually', 'USD 100 EUR']) {
    assert.equal(formatFinancialAmount(input), input);
  }
  assert.equal(formatFinancialAmount(''), '—');
  assert.equal(formatFinancialAmount(null), '—');
  for (const input of ['', null, 'not disclosed', '-50', '9007199254740992']) assert.equal(formatValuation(input, true), '—');
});
