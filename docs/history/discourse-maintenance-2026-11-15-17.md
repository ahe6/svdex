# Historical Discourse maintenance reviews

These November 15–17 notes record earlier states and completed work. They are not
the current task list or operating instructions. Use [current maintenance](../discourse-maintenance.md)
and the [active findings log](../engineering-review-2026-11-19.md).

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


## Refactoring completed — 16 November 2026

- Styles are split into seven ordered source modules with byte-preserving assembly;
  generated output remains compatible with the existing native installer and
  deployment. Removed superseded composer-label height rules. Moved logo styling
  from Sidebar into Appearance. The historical cascade order is explicit rather
  than silently reorganized by feature. Further consolidation can be incremental.
- Interface owns discovery tabs and generic native label/Chat-entry behavior.
  Sidebar retains links and native color-mode initialization. Offering search,
  autocomplete, route synchronization and matching count are a separate component
  from the screening panel. Event handlers retain their destruction cleanup.
- `TopicDiscovery.install!` owns native query filters, count registration and Home
  scoping, preserving registration order and Guardian authority. Plugin bootstrap
  retains fields/hooks/controllers; financial workflows/storage remain separate.
- `native-defaults.rb` centralizes six existing navigation/event defaults, and is
  packaged/copied for local, fresh-production and preserving-upgrade entry points.
  Its allowlist excludes credentials, permissions, registration, intake and policy
  publishing. Local configuration tests and release-package byte checks cover it.
- Reviewed upstream contracts now include composer/category-chooser/navigation,
  Chat/Users routes and the topic-list/query implementations used by counts.
- Source releases require clean committed source and carry a checksum/revision.
  The manual release-candidate workflow reuses fresh native CI before uploading
  source only. Neither workflow has cloud credentials or deploy/publish authority.

The November 15 review above records the rationale; these items supersede its
first refactor suggestions. Permission-aware large-catalog performance work stays
measurement-driven. No new database schema or frontend framework was introduced.

## Integration and remote-review cleanup — 17 November 2026

The category badge renderer has one registration in the metadata integration.
It composes public onboarding URLs and compact category labels; independent
registrations used to overwrite one another. The native renderer source is now
an explicit upstream contract. Browser checks reproduce that link regression.

Repeated tablet Offering toolbar rules are consolidated into one final container
rule. The design and hidden native directory sizing reference are retained;
replacing that measurement strategy is deferred rather than changing column
geometry during cleanup.

CI runs read-only guest browser checks after native checks, with screenshots at
desktop, tablet and narrow mobile widths. Screenshots require visual review and
are not pixel-diff baselines. The staging workflow can preview an explicitly
reviewed PR head without repository writes; see [cloud development](../cloud-development.md).
The production full-build and backup gates remain unchanged until a separately
validated theme-only/artifact-reuse path is available.

