import test from "node:test";
import assert from "node:assert/strict";
import { sectorDestination, usesSectorFilter, isOverviewDirectory } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-sector-navigation.js";
const settings = { svdex_listings_category_id: 6, svdex_public_offerings_category_id: 117, svdex_private_offerings_category_id: 85 };
const sectors = ["finance", "hardware"];
const parse = args => new URL(sectorDestination({ sectorNames: sectors, ...args }), "https://svdex.invalid");

test("sector selection stays in Home's allowlist and preserves search and Top", () => {
  const url = parse({ url: "/top?search=optical&period=yearly&page=2", home: true, value: "hardware" });
  assert.equal(url.pathname, "/top");
  assert.equal(url.searchParams.get("svdex_home"), "1");
  assert.equal(url.searchParams.get("tags"), "hardware");
  assert.equal(url.searchParams.get("search"), "optical");
  assert.equal(url.searchParams.get("period"), "yearly");
  assert.equal(url.searchParams.has("page"), false);
});
test("changing an offering sector retains company tags and offering filters", () => {
  const url = parse({ url: "/c/offerings/6?tags=svdex%20finance&svdex_company=SVDEX&svdex_valuation=10m-50m", category: {url:"/c/offerings/6"}, value: "hardware" });
  assert.equal(url.pathname, "/c/offerings/6");
  assert.equal(url.searchParams.get("tags"), "svdex hardware");
  assert.equal(url.searchParams.get("svdex_company"), "SVDEX");
  assert.equal(url.searchParams.get("svdex_valuation"), "10m-50m");
});
test("clearing a sector in a native tag route returns to its category without the old sector", () => {
  const url = parse({ url: "/tags/c/discussion/5/finance/6/l/top?tags=finance%20svdex&period=monthly", category: {url:"/c/discussion/5"}, mainTag: "finance", value: null });
  assert.equal(url.pathname, "/c/discussion/5/l/top");
  assert.equal(url.searchParams.get("tags"), "svdex");
  assert.equal(url.searchParams.get("period"), "monthly");
});
test("clearing Home's only sector restores its default feed", () => {
  const url = parse({ url: "/latest?tags=finance&svdex_home=1&match_all_tags=true", home: true, value: null });
  assert.equal(url.pathname, "/latest");
  assert.equal(url.search, "");
});
test("The simple sector selector serves Home and Discussions; Offerings uses full filters", () => {
  assert.equal(usesSectorFilter(null, null, "discovery.latest", settings), true);
  assert.equal(usesSectorFilter({id:85}, null, "discovery.category", settings), false);
  assert.equal(usesSectorFilter({slug:"discussion"}, null, "discovery.category", settings), true);
  assert.equal(usesSectorFilter({slug:"events",id:124}, null, "discovery.category", settings), false);
  assert.equal(usesSectorFilter(null, null, "companies", settings), false);
});

test("overview directories omit sector selection even with a discussion category", () => {
  assert.equal(isOverviewDirectory("discovery.overview"), true);
  assert.equal(isOverviewDirectory("discovery.discussion-forums"), true);
  assert.equal(usesSectorFilter(null, null, "discovery.overview", settings), false);
  assert.equal(usesSectorFilter({slug:"discussion"}, null, "discovery.discussion-forums", settings), false);
  assert.equal(isOverviewDirectory("discovery.latest"), false);
  assert.equal(usesSectorFilter({slug:"discussion"}, null, "chat.channel", settings), false);
});
