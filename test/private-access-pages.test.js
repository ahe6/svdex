import test from 'node:test';
import assert from 'node:assert/strict';
import { privateAccessNoticePage } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-private-access-pages.js';
const settings = { svdex_listings_category_id: 6 };
test('private access notice is restricted to Home views', () => {
  for (const path of ['/', '/latest', '/top?period=monthly', '/all-forums', '/new']) {
    assert.equal(privateAccessNoticePage(path, settings), true, path);
  }
  for (const path of ['/c/offerings/6', '/c/offerings/6/l/latest?svdex_view=directory', '/tags/c/offerings/6/svdex/4', '/c/offerings/private-offerings/85', '/c/offerings/public-offerings/117/l/latest', '/private-offerings', '/chat', '/chat/c/lounge/1', '/admin', '/login', '/privacy', '/tos', '/u', '/badges', '/tags', '/search', '/u/svdex/summary', '/u/svdex/preferences', '/u/svdex/messages', '/c/offerings/60', '/c/discussion/5', '/c/discussion/5/l/top', '/tags/c/discussion/5/finance/6', '/t/svdex-seed-preferred/676', '/discussion-forums', '/upcoming-events', '/c/events/124']) {
    assert.equal(privateAccessNoticePage(path, settings), false, path);
  }
  assert.equal(privateAccessNoticePage('/latest'), false);
});

test('directory pages do not show acquisition notices', () => {
  for (const path of ['/companies', '/companies?kind=funds', '/company-directory', '/fund-directory', '/person-directory', '/people']) {
    assert.equal(privateAccessNoticePage(path, settings), false);
  }
});
