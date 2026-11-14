# SVDEX Discourse plugin

This is the server-side part of SVDEX's native Discourse installation. Rendering
lives in the Interface/Sidebar/Appearance themes under `frontend/`.

Use [product scope](../../../../docs/product.md) for current UI behavior,
[maintenance](../../../../docs/discourse-maintenance.md) for code boundaries and
upstream checks, and [production operations](../../PRODUCTION.md) for deployment.

## Native data and custom storage

Company/fund accounts are native users in staff-managed classification groups.
Their disclosures use validated user custom fields; offerings use native topic
custom fields and category moderation. Private access is native group/category
permission, independent of badges or financial submissions. No separate company
entity database is maintained.

Two custom tables store investor submissions:

- `svdex_interest_indications`: canonical per investor/organization/side, with
  consent, scope, expiry, withdrawal and restricted-origin tracking.
- `svdex_offering_bids`: canonical per investor/offering, with USD amount,
  proposed terms, nonbinding confirmation, expiry and withdrawal.

Migrations and ordinary native backups include both tables. A submission is not
an accepted order or executed investment. Updating replaces the saved record;
there is no immutable ledger of every earlier edit.

## Code ownership

- `plugin.rb`: native field, serializer, topic-query and event-hook registration.
- `lib/discourse_svdex/company_directory.rb`: organization classification,
  permission-aware facts and directory queries. `organization_metadata.rb`
  validates supplemental facts and public references.
- `lib/discourse_svdex/financial_submissions.rb`: common exact amount parsing,
  visibility, issuer matching and lifecycle state for financial submissions.
- Controllers: endpoint-specific consent, authentication, ownership, queries and
  writes. Sharing validation does not combine bids with interest aggregates.
- `offering_structure.rb`: native offering children and derived visibility tags.
- `retired_information_pages.rb`: deliberate About/Guidelines route retirement.
- `assets/javascripts/`: small native route declarations and directory adapter.
  Components and presentation belong in the Interface theme.

## Security contract

Financial amounts are validated as positive exact USD cents within the safe
integer bound. Native topic/profile/group visibility remains authoritative.
Hidden/deleted/non-offering topics cannot receive offering-linked submissions.
Bids and history additionally resolve the uniquely tagged visible issuer.
Legacy offering-linked indications retain explicit organization-tag validation.

Only staff edit company financial facts. Individual indications/bids remain
self-only or accessible to authorized staff through explicitly gated review.
Company representatives receive no implicit investor-record access. The owner
history API always scopes to the signed-in member, including for staff, and
returns `private, no-store`. It redacts inaccessible source names/links/terms,
while retaining owner-scoped withdrawal after lost access or disabled intake.

Public aggregates require explicit publication consent and exclude expired,
withdrawn, unconsented and restricted-origin indications. General interest and
bids remain independent. Native private category access is never granted by a
public category adapter, questionnaire submission or achievement alone.

## Main endpoints

All paths below are under `/listings`, except the public navigation routes.

| Endpoint | Purpose |
| --- | --- |
| `company-directory` | Permission-aware native directory data and filters |
| `company-profile/:username` | Organization summary facts and linked activity |
| `company-details/:user_id` | Staff-only disclosure editing |
| `interests/:organization_id` | Own indication and authorized aggregate/review data |
| `interests/:organization_id/:side` | Validated indication update or self-withdrawal |
| `offering-bids/:topic_id` | Own bid or authorized staff review; update/withdrawal |
| `my-interest` | Paginated, owner-only interest/bid management |
| `my-interest/:kind/:id` | Self-withdrawal without requiring source visibility |

`/companies`, `/all-forums`, `/discussion-forums` and `/private-offerings` are
small native route integrations; their rendering stays in the theme. Public
private-access discovery does not disclose private topic titles, tags, authors,
terms or category records.

## Local checks and release

Run `npm run check`, import the local themes, then `npm run check:discourse` from
the repository root. The native suites exercise actual guest/member/staff
requests, financial validation and permission boundaries with rollback-only data.
Theme compilation/export/import and the reviewed upstream contracts are checked.
Follow with desktop/mobile browser review of changed presentation.

Deploy the paired plugin and themes through the preserving upgrade, with ordinary
migrations. Local configuration/fixture scripts refuse production and must not be
used to populate it. Intake and staff-review flags default off; publishing source
code does not activate them or publish policy edits.
