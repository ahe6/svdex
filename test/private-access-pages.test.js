import test from 'node:test';
import assert from 'node:assert/strict';
import { privateAccessNoticePage, organizationDirectoryPage } from '../frontend/discourse-interface/javascripts/discourse/lib/svdex-private-access-pages.js';
const settings = { svdex_listings_category_id: 6, svdex_private_offerings_category_id: 85, svdex_public_offerings_category_id: 117 };
const categories = [{id:6,url:'/c/offerings/6'}, {id:85,url:'/c/offerings/private-offerings/85'}, {id:117,url:'/c/offerings/public-offerings/117'}, {id:5,url:'/c/discussion/5'}, {id:124,url:'/c/events/124'}];
test('private access notice is restricted to Home and authorized offering category/tag views', () => {
  for (const path of ['/', '/latest', '/top?period=monthly', '/all-forums', '/new', '/c/offerings/6', '/c/offerings/6/l/top', '/tags/c/offerings/6/svdex/4', '/c/offerings/private-offerings/85', '/c/offerings/public-offerings/117/l/latest']) {
    assert.equal(privateAccessNoticePage(path,categories,settings), true, path);
  }
  for (const path of ['/companies', '/companies?kind=funds', '/private-offerings', '/chat', '/chat/c/lounge/1', '/admin', '/login', '/privacy', '/tos', '/u', '/badges', '/tags', '/search', '/u/svdex/summary', '/u/svdex/preferences', '/u/svdex/messages', '/c/offerings/60', '/c/discussion/5', '/c/discussion/5/l/top', '/tags/c/discussion/5/finance/6', '/t/svdex-seed-preferred/676', '/discussion-forums', '/upcoming-events', '/c/events/124']) {
    assert.equal(privateAccessNoticePage(path,categories,settings), false, path);
  }
  assert.equal(privateAccessNoticePage('/c/offerings/6',categories,{}), false);
});

test('organization directories use their interest tip, without replacing notices on profiles or topic pages', () => {
  for (const path of ['/companies', '/companies/', '/companies?kind=funds&order=svdex_aum', '/company-directory', '/company-directory/?name=svdex']) {
    assert.equal(organizationDirectoryPage(path), true);
    assert.equal(privateAccessNoticePage(path, categories, settings), false);
  }
  for (const path of ['/u/svdex-company/summary', '/latest', '/c/offerings/6', '/companies/unknown']) {
    assert.equal(organizationDirectoryPage(path), false);
  }
});
