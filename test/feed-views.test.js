import test from "node:test";
import assert from "node:assert/strict";
import { feedViews, feedViewHref } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-feed-views.js";
test("feed defaults separate creation, activity and event dates", () => {
  const context = { filterType: "latest", settings: { svdex_events_category_id: 124 }, routeName: "discovery.category" };
  assert.equal(feedViews({ ...context, category: { slug: "discussion" } }).selected, "latest");
  assert.equal(feedViews({ ...context, category: { slug: "products" } }).selected, "latest");
  assert.deepEqual(feedViews({ ...context, category: { id: 124 } }).views.map(([key]) => key), ["upcoming", "past"]);
  assert.equal(feedViews({ ...context, category: { id: 124 }, query: { svdex_view: "past" } }).selected, "past");
  assert.equal(feedViews({ ...context, routeName: "discovery.overview" }), null);
});
test("view links preserve filters while clearing stale pagination and column ordering", () => {
  const query = { svdex_presales: "1", tags: ["finance", "research"], search: "optics", page: 2, order: "views", ascending: true, svdex_view: "activity" };
  const latest = new URL(feedViewHref("/c/products/177/l/latest", query, "latest"), "https://svdex.invalid");
  assert.equal(latest.searchParams.get("svdex_presales"), "1");
  assert.equal(latest.searchParams.get("svdex_view"), "latest");
  assert.equal(latest.searchParams.get("tags"), "finance research");
  assert.equal(latest.searchParams.has("page"), false);
  assert.equal(latest.searchParams.has("order"), false);
  const top = new URL(feedViewHref("/c/products/177/l/top", query, "top"), latest.origin);
  assert.equal(top.searchParams.has("svdex_view"), false);
  assert.equal(top.searchParams.get("svdex_presales"), "1");
});

// Availability is independent of the feed's ordering.
import { productFilterValue } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-products.js";
test("product availability distinguishes all, launched and pre-sales on native list URLs", () => {
  const settings = { svdex_products_category_id: 177, svdex_presales_category_id: 170 };
  assert.equal(productFilterValue(177, "/c/products/177/l/latest", settings), "all");
  assert.equal(productFilterValue(177, "/c/products/177/l/top?svdex_presales=0", settings), "products");
  assert.equal(productFilterValue(177, "/c/products/177/l/latest?svdex_presales=1", settings), "presales");
  assert.equal(productFilterValue(177, "/c/products/177/none/l/latest", settings), "products");
  assert.equal(productFilterValue(170, "/c/products/pre-sales/170", settings), "presales");
});

test("Home and Discussion use two native activity-based views across overview and chat", () => {
  const context = { filterType: "latest", settings: {}, routeName: "discovery.latest" };
  for (const extra of [{}, {category: {slug: "discussion"}}, {category: {slug: "discussion"}, routeName: "discovery.discussion-forums", filterType: "categories"}, {category: {slug: "discussion"}, routeName: "chat.channel", filterType: "chat"}]) {
    const result = feedViews({...context, ...extra});
    assert.deepEqual(result.views, [["latest", "Latest"], ["top", "Top"]]);
    assert.equal(result.nativeActivity, true);
    if (extra.filterType) assert.equal(result.selected, null);
  }
});
