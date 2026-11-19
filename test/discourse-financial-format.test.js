import test from 'node:test';
import assert from 'node:assert/strict';
import { formatFinancialAmount, formatValuation, formatUsdAmount } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-financial-format.js';

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

test('typed USD facts distinguish units, missing values, zero and invalid amounts', () => {
  for (const [input, expected] of [[0, '$0'], ['0', '$0'], [2000000, '$2M'], ['12500000', '$12.5M']]) {
    assert.equal(formatUsdAmount(input), expected);
  }
  for (const input of [null, undefined, '', ' ', false, true, NaN, Infinity, -1, 1.5, '1.5', 'USD 2M', '1e6', Number.MAX_SAFE_INTEGER + 1]) {
    assert.equal(formatUsdAmount(input), '—');
  }
  for (const [input, expected] of [[0, '$0'], [1, '$0.01'], [10, '$0.1'], [101, '$1.01'], [99999, '$999.99'], [12500000, '$125K']]) {
    assert.equal(formatUsdAmount(input, { cents: true }), expected);
  }
  assert.equal(formatUsdAmount(100), '$100');
  assert.equal(formatUsdAmount(100, { cents: true }), '$1');
});
