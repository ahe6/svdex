# Feed navigation

Implemented locally for issues [#10](https://github.com/ahe6/svdex/issues/10) and
[#11](https://github.com/ahe6/svdex/issues/11); not deployed by this work.

Home and Discussions use Latest / Top, with Latest retaining native recent
activity order. Home includes topics the viewer can access and excludes Feedback
and category description topics. Discussions adds Chat / Overview; its directory and chat routes
show the same four navigation items. There is no separate Activity tab there.
Offerings uses Latest and All securities, Products uses Latest, Top and All
products, and Pre-sales uses Latest and All pre-sales. Products Top uses native
ranking and the same period selector as Home and Discussions. Latest sorts by creation date in these
categories. Existing Top and Activity URLs still work. Activity sorts
by recent topic activity.
Overview/Chat remain their existing destinations. Native topic rendering, access
controls, moderation and ordinary column sorts stay in place.

The view is stored as `svdex_view` on native discovery URLs. Tabs preserve search,
tags and offering filters, while resetting stale
pagination and explicit column order. Native discovery query-param registration
keeps refresh/deep links/Back usable. No parallel topic-feed storage is introduced.

Events uses Upcoming / Calendar. Upcoming combines the installed native Events
plugin's upcoming and ongoing predicates, ordered by start date ascending. Calendar
uses the native Events route, including navigation into previous months. The Past
tab is removed; existing past-filter URLs retain their finished/closed query.
Recurrence/current occurrence, missing end-time semantics and topic visibility
stay with the native Events query. Events without a native event are not included.

Products and Pre-sales have separate sidebar entries. Products opens Discourse's
`/none` category route to exclude subcategories, and Pre-sales opens its existing
public category. The feed tabs preserve each category's scope. Existing
combined URLs and the pre-sales query parameter still work for old links.

At mobile widths, core's single view dropdown is retained. Products uses a native
square filter-icon action to keep the main toolbar compact at 320px. Staff-only
bulk/admin/notification actions can still occupy the native secondary row.

Native transaction tests cover changed creation/activity order, default views,
pre-sales/Top compatibility, ongoing/finished events, chronology and anonymous
permissions. Pure link/default tests and the guest-browser suite cover URL state
and toolbar behavior. Browser automation is a CI check; local visual review uses
desktop and 320px/375px browser views.

Local validation on 2026-11-19: 58 source/unit checks passed; the feed-views,
products, events and help-feeds native groups passed, alongside the entity and
shared-feature regressions. Browser review checked selected view state, pre-sales
with Top, Back, generic Filters/Clear consistency and the 320px one-row toolbar.
The updated automated browser tests are prepared for CI and were not run through
the command line in this session.

The availability button group replaces the earlier checkbox and dropdown.
The launch-only predicate and stable entity-tag profile links have additional
native regression coverage. Browser CI expectations follow the selector UI.


All products uses public product topics. It joins campaigns by product topic ID
and links companies by their Companies tag. Its category filters come from
Sectors. An open campaign sets the Pre-sale stage. Otherwise a concept tag sets
Concept and other products display Shipping. All pre-sales reuses
the table on the Pre-sales URL and shows products with open campaigns. Likes uses
Discourse's topic like count and sorts highest first by default.

All securities uses the native Offering topic query and its filters, limited to
visible topics in the Public offerings category even for staff. Latest continues
to use normal category permissions. Securities and Products can be updated
through the same [public GitHub review flow](public-content-sync.md).
