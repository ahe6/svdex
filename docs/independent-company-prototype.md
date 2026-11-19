# Independent company profile: local feasibility prototype

Status: an isolated local experiment, not a migration or a production feature.
The existing Companies/Funds/People directories, accounts, financial records and
profile URLs remain authoritative. Compare:

- Existing account-backed Summary: <http://localhost:4080/u/svdex-company/summary>
- Independent company profile: <http://localhost:4080/company/svdex>

## What exists

A company has its own ID, slug, name, summary, publication flag and financial facts
in a local `svdex_company_profile_records` table. The optional `official_account_id`
is a native User foreign key with `ON DELETE SET NULL`. A company can exist and
remain published with no account at all. It has no email, password, trust level,
login session or artificial posting history.

The page uses the same `CompanyProfileSummary` renderer as existing organization
profiles: native `DUserStat`, topic-summary components and existing financial
formatting. Its staff editor uses native modal/button controls and the existing
financial field validators. Facts are held in JSONB for this small profile-only
spike; production directory sorting/constraints would need an explicit schema and
index decision. Do not mistake this storage choice for a completed entity system.

Staff can maintain its name, description, total funding and last valuation, and
link/unlink an official account by username. Linking is an explicit staff action,
not proof of ownership and not a self-service claim process. A visible linked
account provides an activity link; account privacy is still checked before exposing
that link. Published company facts have their own visibility, independently of
whether an associated participation account is hidden or deleted.

Offerings and Updates still use native topics, related by the company's explicit
tag and secured by the viewer's native permissions. The local SVDEX record starts
from a one-time copy of the current local account's facts. Later edits do not
synchronize either direction. The browser check unlinked the account; the retained
profile currently demonstrates the no-account case. The original account remains.

## What is deliberately incomplete

- No replacement Companies directory, Funds/People model or bulk conversion.
- Existing interest/bid organization IDs still reference native users. Deleting
  an existing organization account still follows those financial tables' native
  foreign-key behavior; the separate profile does not preserve those old financial
  records automatically. Do not delete existing accounts as part of this spike. When an
  eligible official organization account is linked, the prototype uses that existing
  account-based indication flow; without it, indication actions are absent and
  unknown totals remain dashes. There is no silent financial-record migration.
- Discovery credit still belongs to the current accounts and is omitted here.
- No automatic achievements, account-claim workflow, multiple representatives,
  company-logo upload editor or full company creation/publication dashboard.
- No external product/website changes or new production database migration.

These are real remaining integration costs. The profile and staff editor are
straightforward; migrating the directory, associations, attribution and financial
record relationships is the larger job.

## Local setup and boundaries

The backend module/routes load only for `localhost:4080`. Each request also checks
that local boundary and that the explicitly created table exists. Client routing
is likewise limited to that exact local origin. No prototype route/table is
installed on production or staging by the release configuration.

After stopping the local watcher, the first installation needs `npm run sync:plugin`
because a native client route was added. Then:

```sh
docker cp deploy/discourse/setup-company-profile-prototype-local.rb miscdex-forum:/tmp/setup-company-profile-prototype-local.rb
docker exec -u discourse miscdex-forum bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/setup-company-profile-prototype-local.rb'
npm run sync:styles
```

The setup script creates the local table and initial record, preserving an existing
record's edits. Normal UI iteration uses `npm run dev`. Never copy the local
database or seeded company financials into production.

`npm run check:discourse -- independent-company` creates the optional local table
if necessary, but rolls back its scenario records. It checks account-independent
creation, guest publication, staff-only writes, financial validation, unlinking,
linked-account privacy, unchanged account facts and account deletion. Existing
company and theme checks protect the shared renderer's original use.

## Evaluation

This demonstrates that we can keep the familiar summary UI and native topics
without making the company itself a user. The custom addition is a small model,
permission-aware endpoint and staff form; Discourse still supplies authentication,
UI components, logging and database/backup infrastructure.

Before deciding on migration, build one directory slice and define typed entity
references for bids/interest/discoveries. Choose publication/claim/representative
rules explicitly. Avoid running two authoritative financial models indefinitely.
No decision to replace the current account-backed implementation is implied by
this experiment.

## Validation

All 54 source/package tests and the complete 35-group native suite passed. The
independent-company checks were rerun after the final raw tag-ID redaction change.
Chrome checks covered staff editing, unlinking and reloading, native linked topic
sections and the 375px layout without page overflow. The retained SVDEX prototype
is account-free; its original participation account and financial records remain.
