import test from 'node:test';
import assert from 'node:assert/strict';
import { privateAccessNoticePage } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-private-access-pages.js';
const settings = { svdex_listings_category_id: 6, svdex_private_offerings_category_id: 85 };
const categories = [{id:6,url:'/c/offerings/6'}, {id:85,url:'/c/offerings/private-offerings/85'}, {id:5,url:'/c/discussion/5'}];
test('private access notice covers public discovery and profiles without intruding into account or chat flows', () => {
  for (const path of ['/', '/latest', '/top?period=monthly', '/all-forums', '/c/offerings/6', '/c/offerings/6/l/top', '/tags/c/offerings/6/svdex/4', '/c/offerings/private-offerings/85', '/companies', '/companies?kind=funds', '/u', '/badges', '/tags', '/search', '/u/svdex/summary', '/c/discussion/5', '/t/svdex-seed-preferred/676', '/discussion-forums', '/upcoming-events']) {
    assert.equal(privateAccessNoticePage(path,categories,settings), true, path);
  }
  for (const path of ['/private-offerings', '/chat', '/chat/c/lounge/1', '/admin', '/login', '/privacy', '/tos', '/u/svdex/preferences', '/u/svdex/messages', '/c/offerings/60']) {
    assert.equal(privateAccessNoticePage(path,categories,settings), false, path);
  }
  assert.equal(privateAccessNoticePage('/c/offerings/6',categories,{}), false);
});
