import test from "node:test";
import assert from "node:assert/strict";
import { feedViews, feedViewHref } from "../frontend/discourse-interface/javascripts/discourse/lib/svdex-feed-views.js";
test("feed defaults separate creation, activity and event dates", () => {
  const context = { filterType: "latest", settings: { svdex_events_category_id: 124 }, routeName: "discovery.category" };
  assert.equal(feedViews({ ...context, category: { slug: "discussion" } }).selected, "latest");
  const settings = {
    ...context.settings,
    svdex_listings_category_id: 6,
    svdex_public_offerings_category_id: 66,
    svdex_private_offerings_category_id: 67,
    svdex_products_category_id: 177,
    svdex_presales_category_id: 170,
  };
  for (const [id, label] of [[6, "All securities"], [66, "All securities"], [170, "All pre-sales"]]) {
    assert.deepEqual(feedViews({ ...context, settings, category: { id } }), {
      selected: "latest", views: [["latest", "Latest"], ["directory", label]],
    });
  }
  const products = { ...context, settings, category: { id: 177 } };
  const productViews = [["latest", "Latest"], ["top", "Top"], ["directory", "All products"]];
  assert.deepEqual(feedViews(products), { selected: "latest", views: productViews });
  assert.deepEqual(feedViews({ ...products, filterType: "top" }), { selected: "top", views: productViews });
  assert.deepEqual(feedViews({ ...products, query: { svdex_view: "directory" } }), { selected: "directory", views: productViews });
  assert.deepEqual(feedViews({ ...context, settings, category: { id: 67 } }).views, [["latest", "Latest"], ["top", "Top"]]);
  assert.deepEqual(feedViews({ ...context, category: { id: 124 } }).views.map(([key]) => key), ["upcoming"]);
  assert.equal(feedViews({ ...context, category: { id: 124 }, query: { svdex_view: "past" } }).selected, "past");
  assert.equal(feedViews({ ...context, routeName: "discovery.overview" }), null);
  assert.deepEqual(feedViews({ ...context, category: { id: 124 }, routeName: "discourse-post-event-upcoming-events", filterType: "svdex-events-calendar" }), { selected: null, views: [["upcoming", "Upcoming"]] });
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

test("Home and Discussion use two native activity-based views across overview and chat", () => {
  const context = { filterType: "latest", settings: {}, routeName: "discovery.latest" };
  for (const extra of [{}, {category: {slug: "discussion"}}, {category: {slug: "discussion"}, routeName: "discovery.discussion-forums", filterType: "categories"}, {category: {slug: "discussion"}, routeName: "chat.channel", filterType: "chat"}]) {
    const result = feedViews({...context, ...extra});
    assert.deepEqual(result.views, [["latest", "Latest"], ["top", "Top"]]);
    assert.equal(result.nativeActivity, true);
    if (extra.filterType) assert.equal(result.selected, null);
  }
});
