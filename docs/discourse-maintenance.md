# Discourse maintenance

## Runtime boundaries

- `frontend/discourse-interface/`: client components, templates, controllers and
  routes. The initializer only checks that the backend is present and registers
  the feature integrations below.
- `frontend/discourse-sidebar/`: native sidebar links, ordering and navigation.
- `frontend/discourse-appearance/`: layout and appearance within the native theme.
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

Registration stays centralized and plugin-guarded. Components perform rendering;
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

```sh
npm run check
bash scripts/discourse-local.sh appearance
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


## Architecture review — 15 November 2026

Reviewed the current themes, plugin registrations/controllers/models/migrations,
native integration contracts, local setup, release boundaries and CI. The theme
versus plugin split is appropriate; there is no reason for a broad rewrite. This
review did not benchmark a large production dataset.

### Keep these boundaries

- Appearance, responsive layout, forms, profile summaries and navigation belong in
  the three themes. Interface already registers five feature integration modules
  rather than one large initializer.
- Validation, private visibility, numeric filtering/sorting, consent, bids and
  interest records belong in the plugin. Client-side category choices and labels
  are UX, not authorization. Exact filtered offering counts are likewise a backend
  responsibility; native pinning makes counting rendered rows inaccurate.
- Keep the plugin's small route declarations and directory adapter: they are the
  transport contract for plugin endpoints, not presentation that must be moved
  merely to make the plugin smaller.
- Native user/group accounts, topic fields, category review and private-category
  permissions remain a useful base. Companies do not need another entity table
  for the current product. Financial submissions do need their two custom tables,
  unique indexes, foreign keys, consent rules and server checks.
- Keep interest and offering bids separate despite similar forms. Both use exact
  USD cents and owner-scoped writes; public aggregation has different visibility
  and publication-consent rules from private proposed terms. The shared financial
  validator is an appropriate amount of reuse.
- Keep paired plugin/theme releases, ordinary native backups, guarded local
  fixtures and rollback-only native checks. Official hosting still requires
  accepting the remaining plugin to preserve every current feature.

### Refactor order

1. **Consolidate SCSS before changing designs again.** `common.scss` is over 1,000
   lines with repeated toolbar/mobile rules and superseded declarations (for
   example, composer-label min-height is set to 2.8em and later reset to zero).
   Group rules by feature, remove overridden declarations after checking selector
   scope, then consider native-supported partials. Preserve the computed styles
   and capture desktop/mobile baselines; changing the cascade while merely moving
   blocks would be a regression.
2. **Clarify frontend ownership.** Sidebar currently also registers discovery
   tabs, tag-heading changes and Chat-entry behavior. Those fit the Interface
   discovery integration better. Keep Sidebar focused on native links/order and
   move global logo appearance to Appearance in a separately verified change.
   Split the misleadingly named `svdex-tag-group-filters` into offering search/
   autocomplete/count and the offering screening panel; it now owns both.
3. **Share safe native defaults.** Local, fresh-production and upgrade scripts
   repeat feature and navigation configuration. Nested replies were just aligned
   explicitly across these paths. Extract only a small allowlist of shared native
   feature/presentation defaults. Keep hostname guards, credentials, environment
   permissions, intake switches, policy publishing and fixture setup separate.
   Do not replace guarded upgrade scripts with a universal reset/setup command.
4. **Complete upgrade-contract coverage.** Hash checks currently cover 11 native
   implementations, but not every method override. Add reviewed sources for the
   composer service, category chooser, native navigation/draft control, Chat route
   and Users route as those integrations are refactored. Prefer supported outlets
   and transformers when equivalent; hashes require review on change but do not
   prove semantic compatibility.
5. **Improve fresh-install verification for refactor/release batches.** The source
   workflow runs on pushes. Native CI runs on public contribution PRs or manual
   dispatch, not every main push; the local native run uses the existing container.
   Use a successful clean-install native run as evidence before releasing a large
   refactor. Preserve its rollback/privacy tests and isolated fixture guards.

### Defer until measurements justify it

Company numeric filters cast validated native custom-field values, and the Users
organization-count sort scans visible organizations before pagination. Exact
offering totals add a count query. These are sensible for the current small
catalog, but should be profiled with representative data before introducing
indexes, materialized summaries or a separate company schema. Any caching must
respect the visitor's permissions; a global cache of private-aware counts is not
a safe optimization.

No obvious reason was found to move remaining authorization or financial storage
into themes, combine financial workflows, replace native accounts, or create a
separate frontend application. Refactors above should be small behavior-preserving
changes, with the current source/native checks and targeted visual comparisons.
