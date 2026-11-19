# Independent company profile: local feasibility prototype

Status: an isolated local experiment, not a migration or a production feature.
The Companies, Funds and People sidebar links now open independent directories
locally. Existing accounts, their financial records and profile
URLs are preserved for comparison; no records have been converted. Compare:

- Independent directory: <http://localhost:4080/company-directory>
- Original account-backed directory: <http://localhost:4080/companies>
- Existing account-backed Summary: <http://localhost:4080/u/svdex-company/summary>
- Independent company profile: <http://localhost:4080/company/svdex>
- Independent Funds: <http://localhost:4080/fund-directory>
- Independent People: <http://localhost:4080/person-directory>
- Original People comparison: <http://localhost:4080/people>

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
that link. Published company facts and company-wide interest have their own visibility,
independently of whether an associated participation account is hidden or deleted.

Offerings and Updates still use native topics, related by the company's explicit
tag and secured by the viewer's native permissions. The local SVDEX record starts
from a one-time copy of the current local account's facts. Later edits do not
synchronize either direction. The browser check unlinked the account; the retained
profile currently demonstrates the no-account case. The original account remains.
General interest no longer depends on it.

## Directory, interest and discovery slice

The independent directory reuses the existing Companies template, native responsive
table, column menus, mobile search/filter modals and financial formatting. Search,
monetary ranges, sector/stage/location/open-offering filters, ordering and pagination
query independent records. SVDEX and Northstar start from one-time local copies;
there is no ongoing synchronization with account fields.

Interest remains in the native plugin's existing indication table, with an explicit
nullable `company_profile_id` instead of a fabricated organization User ID. Local
schema setup adds a constraint requiring exactly one target, separate unique indexes
per investor/target/side, and a restrictive company foreign key. Existing account
indications are untouched. General company interest works with no linked account,
including exact cents, consent-only public totals, expiry, editing and withdrawal
through My Bids. The shared modal accepts an explicit endpoint; company references
cannot be mistaken for numerically identical account references. Company-wide
interest cannot claim an offering source in this slice.

Discovery uses the existing discovery/audit tables, with independent current and
original company references. Staff use the existing review component under Manage
discovery credit. Reviewed credit appears on the company profile and contributes to
the contributor's existing discovery summary/history before shared pagination.
Unpublished profiles and hidden contributors do not leak public credit or totals;
original timestamps and original contributor IDs retain their existing protection.

## What is deliberately incomplete

- Public data files for Funds/People, key-person/related-entity editing, public dataset export,
  bulk conversion and a production migration.
- Existing account-based interest, bids, topic issuer resolution and attribution
  are **not** automatically transferred or merged with independent records.
- Bids still target native offerings and account-backed issuers. Company-wide
  indications use independent profiles; no implicit total combines both identities.
- No automatic achievements, account-claim workflow, multiple representatives,
  logo upload editor or complete company creation/publication dashboard. Add company
  still submits the existing staff application, preserving its private-topic inbox.
- The local directory caps its candidate set at 500 and computes derived facts before
  pagination. It is a functional comparison slice, not a production-scale query design.
- No external product/website changes or production database migrations.

These remain real integration costs. A profile, directory, interest and discovery
slice is working; production conversion and ownership are still separate work.

## Local setup and boundaries

The backend module/routes load only for `localhost:4080`. Each request also checks
that local boundary and that the explicitly created table exists. Client routing
is likewise limited to that exact local origin. No prototype routes, tables or relationship columns are installed on production or
staging by the release configuration. Stop/restart the local server after first
schema setup so existing worker schema caches see the new columns.

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

The directory and explicit interest/discovery references now work locally. Before
production migration, resolve bid/topic issuers and choose publication/claim/representative
rules explicitly. Avoid running two authoritative financial models indefinitely.
The experiment now extends to Funds and People; production replacement remains a
separate migration/release decision.

## Validation

The expanded independent-company native check covers no-account interest, exact
amounts and consent changes, private owner history, edit/withdraw after publication
changes, directory search/ranges and discovery review/audit/visibility. Scenario
records roll back. Existing financial/discovery/application checks remain required.
The retained SVDEX prototype is account-free; its original participation account and
financial records remain.


Browser review of this extension covered desktop/mobile directory search, a monetary
range menu, account-free interest submission/edit/withdraw through My Bids, staff
review controls and the existing Add company application modal. The desktop Chat
DM route normally redirects to the last channel; a small theme route override keeps
its native inbox list visible on desktop, with an upstream-source fingerprint to
flag behavior changes during upgrades. No application/private-topic setting was disabled.


Validation for the directory/relationship extension: 54 source/package tests passed,
and ten relevant native groups passed (independent-company, upstream-contracts,
companies, public-interest, my-interest, discoveries, native-workflows, member-flows,
interface-theme, and marketplace-flows). Desktop/mobile browser review verified no page overflow at
375px; the test indication was withdrawn after exercising My Bids. The full 35-group
release suite was not rerun for this local-only extension.


### Directory design parity and interest entry point

Independent identities retain the original native `user-info small`, 48px image,
name-line and two-line summary structure. Logos are native Upload records with
company-owned UploadReferences, independent of the optional participation account;
missing logos use Discourse's standard fallback. Local setup copies the existing
logos and public key-person/related-entity associations once, without overwriting
later company edits. The directory uses the same native global interest notice.

Companies and Funds have a secondary Buy / Sell action next to Add company/
Add fund. Native SelectKit searches the corresponding authorized directory, then
Buy/Sell selection opens the existing indication modal. Amount shortcuts remain.
On mobile the action shares the existing count row to preserve the heading/search/
filter/plus row. This change does not submit an indication until the existing
confirmation and save step is completed.

The design restoration passed the 54 source/package checks and focused native
independent-company/interface-theme checks. Native upload references and public
logo payloads are covered. Browser review compared the original row markup, verified
both logos loaded at 48px, exercised searchable Company/Sell and Fund/Buy selection,
and checked the toolbar at 320px and 375px without document overflow. No new
financial indication was submitted during this visual/entry-point check.


### Reviewed public data-file slice

SVDEX's independent profile now projects `directory/companies/svdex.json` into the
same local database record. File-owned facts use a stored content revision and
snapshot; direct edits to them are rejected, and imports refuse unreconciled database
drift. Logos, account linking, publication and financial/discovery records remain
operational database state. The first file intentionally has unspecified financial
figures rather than inheriting the earlier local account's invented amounts.

Suggest changes sends a native private review topic, with a structured proposed
public document and base revision. Staff can prepare that document as a candidate
file and review it through GitHub; submissions never auto-publish or grant ownership.
See [the catalog workflow](company-catalog.md). This is a working local slice, not a
production deployment integration. Funds/People use staff-maintained database
facts for now; they are not silently imported into the company-only JSON format.

### Funds and People extension

The shared local profile record has a constrained `kind` (companies/funds/people),
optional account link and independent native Upload reference. Its original
company-prototype table/class names are retained in this local slice; do not add
three parallel entity databases. A production schema and public file formats still
need a deliberate migration design. The installer is
`deploy/discourse/setup-entity-profiles-prototype-local.rb`: it copies existing local
facts once, preserves edits on rerun and never runs in release configuration.

Funds reuse the existing directory columns, AUM sorting/ranges, summary renderer,
native-topic offerings/updates and explicit profile interest/discovery references.
Their interest stays separate from the old account's amounts. People retain their
existing directory layout, background, current roles, location and sourced net-worth
display, with a new lightweight professional summary. A person accepts no financial
interest. Key-person links now reference independent people; affiliations are the
reverse of those explicit references, not name matching or native group membership.
Unpublished organizations are omitted from public affiliations and filter choices.

Staff can edit fund/person public facts and optional account links through native
modal controls. Net-worth edits require the existing public HTTPS source/date/basis
validation; unknown amounts remain unknown. Native account privacy controls the
optional participation/activity link, not the curated entity's publication state.
Account deletion/unlinking does not remove the directory profile or its references.

The localhost-only routes are `/fund-profiles`, `/fund/:slug`, `/fund-directory`,
`/person-profiles`, `/person/:slug` and `/person-directory`. Existing `/companies`
and `/people` remain comparison routes; production routes and original accounts
are unchanged. Discovery history includes each independent profile's actual kind
before shared pagination. No existing account discovery/financial records are
automatically duplicated into the new profiles.

Validation on 2026-11-19: 58 source/unit checks and 13 relevant native groups
passed across the entity extension and feed-tab work. Browser review covered both
independent directories and profiles, fund Buy / Sell selection, person editing,
public links and mobile rows, plus the feed controls at desktop/375px/320px.
No production profile/account conversion or financial-data transfer was performed.
