# Discourse maintenance

Current guidance. See the [active engineering findings](engineering-review-2026-11-19.md)
for confirmed problems, fixes and remaining work. Earlier reviews are
[archived](history/discourse-maintenance-2026-11-15-17.md).

## Runtime boundaries

- `frontend/discourse-interface/`: client components, templates, controllers and
  routes. The initializer only checks that the backend is present and registers
  the feature integrations below.
- `frontend/discourse-sidebar/`: native sidebar links/order and native color-mode initialization.
- `frontend/discourse-appearance/`: ordered editable `styles/` modules and a
  generated `common.scss` distributed to the native theme. Run `npm run build:styles`;
  do not edit the generated file. No extra compiler runs in production.
- `deploy/discourse/plugins/discourse-svdex/`: permission-aware data queries,
  serializers, validation, financial records, hooks and client route declarations.
  This remains a custom-plugin installation, not a theme-only site.

The Interface integrations are grouped under `javascripts/discourse/integrations/`:

| Module | Responsibility |
| --- | --- |
| Discovery navigation | Native breadcrumbs, tag/filter navigation, Chat shell and discovery controls |
| Private access | Public onboarding choices and notice; never private topic authorization |
| Organization profiles | Company membership requests, directory choices and summary selection |
| Topic metadata | Compact category names and native tag color markers |
| Offering topics | Composer/first-post details, review details, topic rows and financial column |

Feature registration stays centralized and plugin-guarded. Generic native label/
Chat-entry behavior has its own Interface API initializer and remains usable
without the backend. Discovery tabs belong to the Interface integration, not Sidebar. Components perform rendering;
server controllers remain authoritative. Both Overview routes use the shared
`svdex-overview-directory` component, while their controllers choose their own
secured category sets. Ordinary native user and discussion views remain native.

`FinancialSubmissions` owns exact USD-cent parsing, active organization and
visible-offering checks, issuer matching for bids/history, and record state.
Indication and bid controllers retain their different consent rules, ownership,
expiry and aggregation behavior. Legacy offering-linked interest retains its
explicit company-tag validation; it shares the hidden/deleted-topic rejection.
Do not merge interest and bids merely because they share form controls.

## Local verification

Use `npm run dev` for ordinary UI edits. Before configuration imports or native
checks, stop the watcher. After a batch:

```sh
npm run dev:stop
npm run check
npm run sync:themes  # Interface/Sidebar changes; sync:styles for full appearance import
npm run check:discourse
```

The appearance command imports Sidebar and Interface before the parent theme.
It does not install new backend files. For Ruby-only plugin changes, copy the
plugin into the local container and restart Unicorn. New plugin client route
maps require rebuilding the plugin JavaScript and application assets as well.
Use the preserving production upgrade for a release, not local setup commands.

Run native checks after theme import and before the browser review. Native checks
include theme export/import and temporarily change feature flags in isolated
runners; concurrent UI review can therefore show transient state. Financial and
permission checks roll back their records and restore settings. Temporary UI
records should likewise be scoped and removed after review.

## Discourse upgrades

`deploy/discourse/upstream-contracts.json` records the reviewed native source
hashes for the components/routes/controllers we extend. The native suite fails
when those sources change or disappear. These conservative checks request review;
they do not prove semantic compatibility on their own.

Routine code delivery requires the existing core version to match the release
pin. A core upgrade is a separate maintainer operation; follow the rehearsal and
backup/restore plan in the findings log before changing that live version. Do not
remove the version guard merely to make a deployment pass.

On an upstream change:

1. Compare the changed native implementation with its named SVDEX integration.
2. Update our extension only as needed. The copied Chat shell should differ from
   native only by its Discussions navigation import and insertion.
3. Review and update the affected source hash and the recorded Discourse revision.
   Do not regenerate hashes merely to turn a failing check green.
4. Run source/native checks and desktop/mobile review of affected routes,
   including guest/member/staff permissions and plugin-absent behavior if relevant.

Checks read local Discourse sources; they need no remote fetch or credentials.
Add a contract entry when introducing another native class override or copied
shell. Prefer supported outlets and value transformers over copying templates.

## Releasing

See [production operations](../deploy/discourse/PRODUCTION.md). Commit paired
plugin/theme changes together, deploy a reviewed source revision, and keep
financial intake flags separate from presentation release. Native users, groups,
topics, fields, indications and bids all belong to ordinary Discourse backups;
there is no separate browser or external database to maintain for this feature.


## Directory layout and shared controls

The Companies/Funds table now declares its identity track directly:
`minmax(24em, 4fr)`, followed by one track per directory fact. The identity width
keeps the native username-plus-one-statistic allocation (about 380px at the
reviewed desktop width); the table no longer mounts an invisible Users table,
removes duplicate IDs or observes its layout. Native `DResponsiveTable` still
owns the responsive breakpoint and stacked mobile rows. Financial tracks retain
their intrinsic header widths and existing horizontal overflow behavior.

`svdex-filter-trigger` is a small presentation component for directory and modal
filter buttons. Pages still own their filter state, available choices, dialogs
and focus restoration. Do not turn this into a generic toolbar framework or move
permission decisions into it. Native SelectKit filter dropdowns remain native.

`formatUsdAmount` formats typed, nonnegative integer-dollar facts and explicit
integer-cent totals; missing/invalid values stay undisclosed instead of becoming
zero. The same directory facts feed profile summaries. Authored offering terms
remain free-form: qualified amounts, currencies and ranges must not be silently
converted to exact numeric facts. This change does not migrate stored data or
change bid/interest validation, consent, aggregation or visibility.

### Release and data-model decisions

Keep the current release gates: native checks, the matching staging source tree,
then production. Repeated source checks cost seconds; full Discourse rebuilds
cost most of the time. Skipping checks would not meaningfully improve ordinary
UI iteration, which now uses the local warm theme watcher. A theme-only release
path would need an explicit plugin/core/theme compatibility manifest, atomic
paired updates and rollback tests. Defer that additional deployment mode until
release timings justify maintaining it; do not infer safety from changed paths.

Keep account-backed organization profiles and native custom fields. Financial
submissions already have typed cents, foreign keys and server-side checks. A
migration of authored offering text needs a separate schema and authoring
workflow decision, rather than guessing numeric values during this cleanup.
Profile visibility-aware directory queries with representative data before adding
caches or denormalized tables; no large-directory throughput claim is established.

## Directory query boundaries

Directory search now narrows the candidate relation before Ruby profile visibility
checks. Those checks still precede native counts, sorting and pagination. People
organization filters resolve only the requested organization. Classification
exclusions remain SQL subqueries instead of materialized arrays of every ID.

Company/Fund fact population, location options and People/Users organization
references use native `User.custom_fields_for_ids` for typed batch reads. Loading
`user_custom_fields` as an Active Record association does **not** preload native
`user.custom_fields`. Keep the bulk results local; do not replace a User's editable
field cache with a partial preload proxy. Fund classification and offering category
URLs are also loaded once per fact batch. No visitor-permission cache is added.

The bounded query-cost check uses transaction-scoped records, cold associations
and disabled SQL caching. In the reviewed local scenario, company fact population
changed from 14 queries for one row / 42 for eight rows to 15 / 15. This measures
fact loading, not complete HTTP latency or large-catalog capacity. The check also
ensures a username search does not check every unrelated profile. Full unfiltered
catalog visibility and association-option scans still exist; do not claim those
have become constant-time queries.

The remaining identity DOM adapter is intentional: native `DUserInfo` hardcodes
user-card attributes on its identity links and exposes no per-instance summary
link/no-card option. Keep the tiny scoped adapter rather than copying its whole
markup. Its native source is now checked during upgrades, alongside native
profile visibility, directory query ordering and custom-field decoding. Existing
Chat shell, composer and navigation contracts remain in place.

### Financial field boundaries

| Facts | Storage / interpretation |
| --- | --- |
| Company funding, last valuation, fund AUM and fund size | Typed whole USD integers; AUM and fundraising target remain distinct |
| Offering post-money valuation | Positive whole USD integer; not a SAFE cap |
| Other authored offering terms | Bounded text preserving currency, ranges and qualifications; instrument-specific display does not erase hidden values |
| Interest and bids | Validated positive integer USD cents, separate consent/state/visibility rules |
| Personal net worth | Sourced text/range with date and basis; never inferred from company valuation |

Reviewed composer field limits, instrument choices, directory ranges and existing
native validation/serialization checks. No schema migration or conversion of
free-form offering text is justified by this review.

### CI preparation

The successful tooling PR's native run took about 19 minutes: fresh forum setup
6m45s, native checks 4m17s, browser preparation 4m47s, browser checks 2m46s, plus
small checkout/report steps. Browser preparation now overlaps forum setup; both
must succeed before native/browser checks proceed. This removes serial waiting,
not test coverage. Actual savings depend on runner resources and download speeds.
No Docker-image cache, shared production data or deployment credentials are added.
