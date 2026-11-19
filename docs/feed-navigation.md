# Feed navigation

Implemented locally for issues [#10](https://github.com/ahe6/svdex/issues/10) and
[#11](https://github.com/ahe6/svdex/issues/11); not deployed by this work.

Home, Offerings, Products and Discussions share Latest / Activity / Top. Latest
means creation date, not the default Discourse bumped-date interpretation.
Activity uses native topic activity and Top retains native engagement scoring.
Discussions defaults to Activity; the others default to Latest. Overview/Chat
remain their separate existing destinations. Native topic rendering, access
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

Products stays mixed by default. Its native checkbox Pre-sales only adds
`svdex_presales=1`, restricting the secured result to the pre-sale child category
before pagination. It is independent of Latest / Activity / Top, not another sort.
The existing Type selection in Filters uses the same classification; clearing
filters removes the marker. No keyword matching or securities reclassification.

At mobile widths, core's single view dropdown is retained. The checkbox sits on
that row. Products uses a native square filter-icon action on mobile to make room
without wrapping the primary creation action at 320px; the other filter triggers
keep their existing labeled presentation. Staff-only bulk/admin/notification
actions can still occupy the native secondary row.

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
