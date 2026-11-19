# Engineering review and active findings — 19 November 2026

This is a maintained work queue, not a declaration that the whole site is free of
bugs. Review baseline: directory/tooling work through `ab36255`, followed by the
fixes in this review branch. Changes are local until reviewed, staged and released.

## Assessment and decisions

Keep the existing foundation: upstream Discourse, three native themes, one server
plugin, ordinary Discourse backups and an isolated staging host. There is no
core fork or parallel application/database to remove. Company/fund/person accounts
remain native users; offerings/products remain native topics. Private bids and
indications require authoritative server logic and their own records.

Use supported outlets, transformers and native components first. Keep a small
reviewed override when an equivalent extension point is absent; duplicating the
whole native component to remove a tiny adapter would increase upgrade exposure.
Do not move access checks into themes to claim theme-only portability. No managed
host has agreed to support this plugin, and no newer Discourse revision was
installed as part of this review.

## Findings register

| ID | Priority | Status | Finding and action |
| --- | --- | --- | --- |
| R01 | P2 | Fixed; release pending | Saved bid/interest inputs divided cents into a floating-point dollar number. At the supported maximum, `9007199254740991` cents reopened as `90071992547409.9`, losing a cent. Use exact integer-to-decimal conversion for editable inputs and full history amounts; retain native locale formatting and test the full supported boundary. |
| R02 | P2 | Fixed; release pending | My Bids withdrawal confirmation dereferenced a missing organization after the API redacted lost-access records. Use a generic confirmation when the source is unavailable; preserve owner-only withdrawal and native confirmation dialogs. |
| R03 | P2 hardening | Fixed; release pending | Indication/bid responses relied on Discourse's configurable browser-back caching policy, unlike owner history. Explicitly set `private, no-store`; test with native browser-back caching enabled. This was not a reproduced shared-cache disclosure. |
| R04 | P2 maintenance | Fixed; release pending | Current instructions were mixed with superseded refactor proposals, public product text used older filter labels, and the plugin inventory omitted discovery tables. Archive earlier reviews, correct the inventory/labels and label managed-host pricing research historical. |
| R05 | P3 maintenance | Fixed; release pending | Dependabot watched Actions but not the now-active npm browser/development tooling. Add bounded weekly npm update PRs; retain review, checks and staging gates. This does not update Discourse pins automatically. |
| R06 | P2 performance | Open: measure next | Topic-list offering serialization resolves the Companies tag group and visible company-tag IDs per offering row. This can repeat whole-group reads; measure a realistic mixed feed before choosing a native list-preload or request-scoped batch implementation. Avoid a global permission cache. |
| R07 | P2 upgrade coverage | Open: bounded follow-up | The production updater requires the live core version to equal the release pin; ordinary deploys cannot upgrade core. Source fingerprints also do not prove compatibility with a newer release. Perform an actual pinned-version upgrade rehearsal on disposable/staging data before a core upgrade. Review changed sources rather than blindly regenerating hashes. |
| R08 | P2 UI coverage | Open: next test batch | Browser CI covers guests; signed-in workflows are checked through native HTTP/Ruby scenarios. It does not automatically exercise every modal lifecycle, lost-access withdrawal dialog, draft resume or mobile signed-in composer. Add a few focused member-browser scenarios rather than an exhaustive click-through suite. |
| R09 | P3 test clarity | Open: consolidate gradually | The plugin includes request specs under `spec/requests`, while repository CI executes the rollback-based native verification scripts. Those specs must not be presented as executed CI coverage. Port or explicitly run them when adopting a standard upstream plugin-test setup; do not create a second full test environment merely for appearances. |
| R10 | P2 capacity | Open: benchmark before redesign | Unfiltered profile visibility, People association options and discovery histories still inspect accessible candidates before pagination. Exact privacy-aware counts need that work today. Test representative catalog sizes before adding indexes, denormalization or caches. Current 1/8-row and 1/6-row query-cost checks are not throughput benchmarks. |
| R11 | Product/retention decision | Deferred | Financial submissions store the current record, not immutable edit history. Discovery events retain original identifiers/snapshots across account merges. Decide retention, anonymization and any financial audit-history requirements before introducing transactional workflows; do not silently change consent or legal policies in a refactor. |
| R12 | P3 behavior edge | Open: reproduce | Offering totals are carried on the first rendered topic. An empty out-of-range page can therefore report zero despite matches on earlier pages. Add a targeted pagination reproduction before changing native TopicList count plumbing. |

| R13 | P2 configuration ownership | Documented; behavior decision pending | Releases reapply Updates/Events permissions, People group policy and other native settings. The updater comment and operations text overstated preservation. Correct those claims now; decide which settings should become bootstrap-only or explicit migrations before relying on admin UI customizations surviving every release. |

P2 means a meaningful correctness/maintenance risk, not necessarily a launch
blocker or an exploitable security vulnerability. Fixed rows remain release
pending until their exact revision has passed the normal staging/release flow.

## Evidence and scope

| Area reviewed | Evidence / result | Limits |
| --- | --- | --- |
| Native frontend integration | All six Interface integration modules; Sidebar registrations; copied Chat shell; identity adapter; composer/category scopes; native source contracts | Fingerprints require review on changes; visual regressions still require browser inspection. |
| Permission boundaries | Financial controllers/shared validator, owner history, discovery visibility, profile/group guards, category/tag adapters, native verification scenarios | No external penetration test or exhaustive concurrency fuzzing. Public adapters do not grant category access. |
| Financial records | Exact-cent server parser, table constraints/FKs/uniqueness, consent/restricted-origin aggregates, bid/interest lifecycle, source redaction, input/display helpers | Current-state records are intentional; no transactional matching/settlement system exists. |
| Public rendering | Native category/tag renderers, HTML escaping boundaries, validated URL helpers, six-digit color validation, public questionnaire link allowlist | A source review is not a general XSS proof. No untrusted HTML renderer was added. |
| Query behavior | Company/People directory queries and typed batch readers, offering queries/counts, attribution history and serializers | Remaining scale risks R06/R10 are explicit; no new global authorization cache is warranted. |
| Delivery and recovery | Source manifests, pinned revisions, staging/prod workflow conditions, OIDC/host targeting, host receipts, preserving upgrade, private pre-release backup | No AWS resource or live configuration was changed/recertified. Previous restore exercise is dated evidence, not a permanent recovery guarantee. |
| Public dataset boundary | Read-only source inspection of sibling `svdex-data` guest client, explicit outgoing field allowlists, redirect/origin restrictions and checksum/SQLite loader design | Not a private Discourse backup; downloaded public copies cannot be recalled. No export was published during this review. |
| Contributor workflow | Fresh-clone source checks from the preceding refactor, root instructions, setup/doctor, fork CI, local watcher and source packaging | Full clean Linux setup is provided by CI; no new cloud-editor environment or per-PR host was provisioned. |

### Source locations for follow-up

- [Plugin registration and offering serialization](../deploy/discourse/plugins/discourse-svdex/plugin.rb)
- [Financial controllers](../deploy/discourse/plugins/discourse-svdex/app/controllers/discourse_svdex/)
- [Shared financial validation](../deploy/discourse/plugins/discourse-svdex/lib/discourse_svdex/financial_submissions.rb)
- [Discovery lifecycle](../deploy/discourse/plugins/discourse-svdex/lib/discourse_svdex/discoveries.rb)
- [Native integration modules](../frontend/discourse-interface/javascripts/discourse/integrations/)
- [Reviewed upstream contracts](../deploy/discourse/upstream-contracts.json)
- [Native CI](../.github/workflows/native-discourse.yml)
- [Current maintenance instructions](discourse-maintenance.md)
- [Production](../deploy/discourse/PRODUCTION.md) and [staging](../deploy/discourse/STAGING.md)

## Validation record

The preceding directory refactor passed 51 source/package tests, all 34 native
verification groups and clean-clone source checks. That evidence belongs to that
revision, not every future change. This review adds exact-input and redacted-source
confirmation regression cases and caching assertions to the native bid/aggregate
scenarios. Final results for this batch:

- Source/package checks: all 54 tests passed, including exact cents, native locale
  display and withdrawal with a redacted source; edited documentation links resolve.
- Native verification: all 34 groups passed, including explicit no-store behavior
  with browser-back caching enabled. Theme compilation/export/import was repeated
  successfully after the final presentation helper change.
- Changed-screen browser review: saved maximum-cent input and full history display
  verified in Chrome; lost-access withdrawal confirmation opens on desktop and at
  375px. Dialogs were cancelled without submitting financial changes. Both
  temporary profiles and their indication/attribution records were removed.
- Production: unchanged.

The following directory-refactor CI run passed in 18m24s, versus 19m04s for the
prior tooling run. Combined forum/browser preparation was 9m13s, versus 11m32s
when serial; native checks took longer in the newer run. These are two ordinary
runner observations, not a controlled benchmark or a promised release speed.

## Work order after this batch

The [refactoring plan](refactoring-plan.md) maps these findings to bounded batches,
including existing cleanup opportunities and what should remain unchanged. It is
a plan, not a claim that the remaining items have been implemented.

1. Measure R06 and representative catalog sizes for R10; optimize the measured
   path without changing privacy-aware counts or adding a parallel company model.
2. Add the small signed-in browser scenarios in R08, covering inaccessible-source
   withdrawal and opening/editing forms, with disposable local data only.
3. Before an upstream upgrade, perform R07's rehearsal and inspect new extension
   points; replace overrides only when the replacement preserves behavior.
4. Define R13's code-owned versus UI-owned settings before refactoring deployment
   configuration; preserve current access/moderation policy until that is decided.
5. Revisit R11 when introducing real transactional workflows or a retention change.

Do not turn every risk into an immediate rewrite. The existing native framework,
permission checks, isolated staging and backup flow are useful foundations.
