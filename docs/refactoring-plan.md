# Refactoring plan

This is the implementation map for the [engineering findings](engineering-review-2026-11-19.md).
A mapped item is not an implemented fix. Preserve current UX, consent, moderation,
private visibility and data unless a separately reviewed behavior change says
otherwise. Work locally and release in batches.

## Already completed

- Styles are seven ordered modules with a generated distribution stylesheet.
- Interface registration is grouped by feature; Sidebar owns navigation links.
- Shared financial validation lives in `FinancialSubmissions`; bids and general
  interest retain separate consent, ownership and aggregation rules.
- Directory facts are shared between tables and profiles, with native typed bulk
  reads and explicit dollar/cent formatting.
- The hidden Users measuring table is gone; filter-trigger presentation is shared.
- Current maintenance guidance is separated from historical reviews.

Do not repeat those reorganizations or create abstractions merely to reduce a
line count. `plugin.rb` is currently about 230 lines of registration/bootstrap,
not a reason by itself to build a registration framework. The small People and
Companies controllers can remain distinct despite inheriting the same native UI.

## Ordered implementation queue

| ID | Batch / outcome | Concrete starting points | Completion criteria |
| --- | --- | --- | --- |
| RF01 | Small behavior-preserving cleanup | My Bids controller still declares removed filter choices/actions and an unused `editLabel`; Companies `loadUsers` adds a flag directly to a supplied params object | Search every caller/template before removal; keep owner-history API filters supported; leave visible labels/actions unchanged. Copy request params before adding the directory flag. Native theme compilation and relevant history/directory checks pass. |
| RF02 | Batch offering-list metadata after measuring | `plugin.rb` offering serializer repeatedly resolves Companies tag-group visibility (R06) | Record mixed-feed query count at representative row/tag counts; use a supported native preload or an explicitly request-scoped batch. Show identical guest/member/staff payloads, including hidden tags. Do not add global permission caching. |
| RF03 | Make release configuration ownership explicit | `configure-upgrade-production.rb`, `configure-marketplace.rb`, People/products/pre-sales helpers (R13) | Inventory each write as bootstrap, explicit migration or ongoing security assertion. Recommended default: create missing setup, preserve ordinary admin changes, fail clearly on invalid access policy. Add rerun/customization tests before changing behavior; private access and moderation remain protected. |
| RF04 | Complete the native integration map | Interface integrations, copied Chat shell, route/controller subclasses and `upstream-contracts.json` (R07) | Inventory each target, supported API versus overridden method, native source dependency, test and removal condition. Check currently unlisted dependencies such as native discovery/categories route/controller inheritance. Prefer a supported replacement only where behavior is equivalent. |
| RF05 | Keep financial/API definitions consistent | Composer field limits/instruments, server field validation, directory ranges and submission presentation | Add narrow contract checks when changing these definitions. Keep typed cents, whole-dollar facts and authored text distinct. Do not introduce a schema generator or merge interest/bid forms merely because fields overlap. |
| RF06 | Consolidate test responsibilities | Native rollback scenarios, unused-in-CI request specs, guest browser suite (R08/R09) | State which runner executes each test. Add a few signed-in browser cases for modal opening, redacted-source withdrawal and draft resume. When moving a scenario to standard upstream specs, avoid permanently maintaining two equivalent suites. Never use real investor data. |
| RF07 | Establish catalog performance budgets | Directory visibility/options, discovery histories and profile serialization (R10) | Measure complete requests with realistic catalog sizes and permission mixes, beyond existing small query-cost checks. Choose indexes/batching from the measured bottleneck. Preserve privacy-aware totals before pagination. Separate this from schema/ownership redesign. |
| RF08 | Keep documentation current and findable | `product.md`, operations, current maintenance, review history | Maintain one current statement of behavior and one active findings log. Move superseded dated explanations to history as they become misleading; repair links. Preserve actual requirements rather than shortening away permission or release constraints. |

RF01 is ready for a small next implementation batch. RF02 starts with measurement.
RF03 starts with the settings inventory and explicit ownership rules, not broad
changes to category permissions. RF04 can proceed alongside that inventory. RF05
is incremental, attached to actual field changes rather than a speculative rewrite.

## Separate work, not cosmetic refactoring

- **Core upgrades:** the production code updater deliberately refuses a different
  core pin. Design and rehearse a separate core/database upgrade with isolated data,
  extension review, backup/restore and rollback checks (R07). Do not remove that
  guard to make a release pass.
- **Retention and audit history:** preserve current records until retention,
  anonymization and immutable financial-history requirements are decided (R11).
- **Offering count edge:** reproduce an empty out-of-range page before changing
  native count plumbing (R12).
- **Organization ownership:** current directories remain account-backed. The
  [local independent-company prototype](independent-company-prototype.md) explores
  a separate record and optional participation account; no migration is approved
  by that experiment. Multi-person organization management still needs explicit
  rules.

## Boundaries to retain

Use native accounts, topics, groups, moderation, messages, Chat/Events and backups.
Themes own rendering, navigation and form controls; the plugin owns authoritative
queries, validation and private records. Tiny native adapters may be less work to
maintain than copied components. A custom plugin is still required for full feature
parity; moving code to a theme does not remove server requirements.

Avoid a second frontend, generic toolbar framework, general-purpose filter engine,
new entity database, custom queue/deployment platform or universal financial form
without a demonstrated need. Share stable presentation/formatting; keep different
permission, consent and workflow rules explicit.

For every batch, record the concrete problem, resulting behavior, relevant checks,
remaining limits and release status in the findings log. Use the fast local watcher
for UI iteration, then stop it before native checks. Documentation-only planning
needs link/source review, not a local application rebuild.
