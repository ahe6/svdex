# Feed navigation

Implemented locally for issues [#10](https://github.com/ahe6/svdex/issues/10) and
[#11](https://github.com/ahe6/svdex/issues/11); not deployed by this work.

Home and Discussions use Latest / Top, with Latest retaining native recent
activity order. Discussions adds Chat / Overview; its directory and chat routes
show the same four navigation items. There is no separate Activity tab there.
Products and Offerings keep Latest / Activity / Top: Latest means creation date,
Activity means native topic activity, and Top uses native engagement scoring.
Overview/Chat remain their existing destinations. Native topic rendering, access
controls, moderation and ordinary column sorts stay in place.

The view is stored as `svdex_view` on native discovery URLs. Tabs preserve search,
tags, offering filters and the Products pre-sales selection, while resetting stale
pagination and explicit column order. Native discovery query-param registration
keeps refresh/deep links/Back usable. No parallel topic-feed storage is introduced.

Events uses Upcoming / Past instead. Upcoming combines the installed native Events
plugin's upcoming and ongoing predicates, ordered by start date ascending. Past
uses its finished/closed predicate and descending start date. Recurrence/current
occurrence, missing end-time semantics and topic visibility stay with the native
Events query. Events without a native event are not included. The native calendar
route remains available, but Calendar is no longer a main Events tab.

Products stays mixed by default. A visible group of native buttons offers All,
Launched and Pre-sales, independent of Latest / Activity / Top. It sits beside the
Products heading on mobile and beside the view tabs on desktop. `svdex_presales=1`
selects the pre-sale child category; `svdex_presales=0` excludes it before pagination.
Here Launched means the normal Products category, not an inferred shipping date.
Native child-category and `/none` routes remain supported. The Type selection in
Filters uses the same classification; clearing filters removes the marker.
No keyword matching or securities reclassification is introduced.

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
