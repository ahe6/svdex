import test from "node:test";
import assert from "node:assert/strict";
import { feedViews, feedViewHref } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-feed-views.js";
test("feed defaults separate creation, activity and event dates", () => {
  const context = { filterType: "latest", settings: { svdex_events_category_id: 124 }, routeName: "discovery.category" };
  assert.equal(feedViews({ ...context, category: { slug: "discussion" } }).selected, "activity");
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
