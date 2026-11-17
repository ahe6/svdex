# SVDEX production operations

## Current source and live state

These procedures describe the self-hosted SVDEX installation. They are not
credentials, authorization to operate svdex.com or a claim that a local clone has
been deployed. Contributors can develop and test without AWS access.

All live configuration, credentials, backup records and operator decisions remain
outside this repository. Use your own domain, verified sender, administrator and
private release input when adapting this installation. Do not copy a development
database or invented financial fixtures into a production service.

## Application structure

- Native Discourse supplies users/groups, categories/topics, moderation, tags,
  bookmarks, messages, Chat, Events, authentication and backups.
- Sidebar, Interface and Appearance are native themes/components. They ship with
  the backend plugin and are imported through native theme tooling.
- The plugin supplies validated company/fund facts, financial queries,
  serializers, private indications/bids and route declarations. A theme-only
  deployment cannot replace those functions.
- Company/fund accounts are native users classified by staff-managed groups.
  Their facts are native custom fields. Offering facts are native topic fields.
- Interest, bids and discovery attribution/audit records use plugin-owned tables,
  included in ordinary database migrations and backups. They do not implement order execution or settlement.

[Product scope](../../docs/product.md) describes current UI behavior and labels.
[Maintenance](../../docs/discourse-maintenance.md) describes source ownership,
local checks and upstream compatibility guards. Historical setup prose should
not override these sources or current production records.

Production helpers resolve the administrator from the private container
`DISCOURSE_DEVELOPER_EMAILS` setting. The mail-event setup uses an explicit
`SVDEX_ADMIN_EMAIL` environment value; do not put personal addresses in source.

## Preparing a release

```sh
npm run check
bash scripts/discourse-local.sh appearance
npm run check:discourse
ruby scripts/prepare-discourse-production.rb \
  .data/discourse-production.json .data/discourse-production-release
```

Use a new output directory for each release. The private input must have mode
`600`; preparation refuses to overwrite output, embeds exact plugin bytes and
records source hashes and Git revision. Commit before generating the release and
verify `source_dirty` is false. No database or invented content is included. Installation `app.yml` contains
private mail credentials; never commit the generated bundle or configuration.

The private production configuration retains the live credentials and reviewed
immutable Discourse/discourse_docker revisions. The preserving release script
requires the same Discourse pin as the running host; an engine/version upgrade
needs a separate reviewed upstream upgrade procedure. Regenerate and test its
package, including upstream-contract checks; updating pins alone is insufficient.

## Upgrading the existing site

Use `aws/upgrade-release.sh`, not the fresh installer. Read its arguments and
checks before running it. Take an uploads-inclusive native backup off-server first. The script preserves
the existing private `app.yml`, builds the paired plugin/theme release, applies
ordinary migrations and imports native themes. It replaces complete theme source
directories so removed modules cannot remain active. It then runs the
bounded production configuration helpers and verifies shipped runtime hashes.
Run the appropriate production workflow/smoke checks separately. The prior image,
configuration and theme exports remain available for rollback.

The upgrade runs `configure-upgrade-production.rb` and then
`configure-marketplace.rb`. These preserve native IDs and permissions, configure
Public/Private offerings, Updates, People and Pre-sales, and synchronize approved
visibility labels. Exemption tags remain staff-assigned. They do not import local
companies/funds, offering fixtures, monetary records or investor memberships.

Do not run local setup/fixture scripts on production. Do not run
`configure-production.rb` or `aws/install-release.sh` against the running site;
those are guarded fresh-install paths. Do not overwrite public access settings
with the closed defaults of a newly prepared installation bundle.

The live environment uses `DISCOURSE_LOGIN_REQUIRED=false` and
`DISCOURSE_ALLOW_NEW_REGISTRATIONS=true`. Environment values override native UI
settings. Changes to runtime environment require recreating the container through
the upstream launcher while retaining shared data. A normal theme import does
not require altering those values.

Before recording a successful release, verify the actual runtime source manifest
and database theme content. Smoke-test guest/member/staff views, public/private
category denial, company/fund filters and summaries, moderation, tags, and the
owner-only financial management page. Review desktop and narrow mobile layouts.
Real Google login, signup confirmation and password-reset email delivery require
live checks; local integration tests cannot establish those outcomes.

## Financial feature activation

These settings default off and production setup does not enable them:

- `svdex_interest_enabled`: nonbinding company/fund indication intake.
- `svdex_interest_staff_preview`: authorized staff record review.
- `svdex_interest_public_totals`: explicitly consented public aggregate amounts.
- `svdex_bids_enabled`: private offering-bid intake.
- `svdex_bids_staff_preview`: authorized staff bid review.

Publish the updated Privacy text for the actual enabled features using the
reviewed source hash and effective-date checks in `apply-site-pages.rb` before
enabling intake. Existing published policies are native staff-editable topics;
source edits alone do not publish them. The updated source covers Tally and
private bids. Preserve prior questionnaire responses if retained.

Public interest totals exclude expired/withdrawn records, legacy unconsented
records and restricted-origin indications. Bids never contribute to those totals.
Bids are private to the submitter and authorized staff with the separate flag;
company representatives do not automatically receive them. History/withdrawal
remain available after feature disablement or access loss, with inaccessible
source details redacted. Keep general interest, offering bids, group access and
accreditation verification as separate concepts.

The private-access questionnaire is now Tally, with manual review and native
staff-case archival. The older Google Form is retained; it is not the current
application entry point. Manual badge/group changes do not establish legal
eligibility for an offering.

## Recovery and operations

Native backups include uploads, custom fields, themes, plugin tables and consent
records. Off-server shipping and health/disk/backup-age alerts are implemented by
`aws/maintenance.sh`. SES delivery/bounce/complaint integration is in
`aws/configure-mail-events.py`. Confirm the currently installed schedules and
alerts during a release rather than assuming historical checks are still current.

Retain a fresh recovery point for each backend upgrade and use an isolated restore
target when testing recovery. Never restore over local development or production
as a verification shortcut. Configure administrator MFA/passkeys and recovery.


## GitHub delivery

Trusted development revisions pushed to `staging` automatically update the isolated
preview at `staging.svdex.com`. Review that site, then merge the same source into
`main`. Relevant main updates run fresh native checks and deploy automatically;
there is no second approval click. Production requires a host-written successful
staging receipt for the exact Git source tree, so a merge/squash commit can retain
its new commit ID while shipping identical reviewed files. Unstaged or changed
source is refused. Documentation-only changes do not trigger delivery. Stale
releases are refused if the branch has advanced. Deliveries are serialized per
environment. See [staging operations](STAGING.md).

The production job builds with `ruby scripts/prepare-discourse-production.rb
--upgrade artifacts/release`. This code-only package has no installation
credentials or environment settings. It cannot initialize a fresh host. The host
keeps its existing private environment, database, uploads and runtime engine pin.
Source-owned themes and bounded marketplace defaults are reapplied. Changing the
Discourse engine pin is a separate reviewed operation, not an automatic upgrade.

`aws/github-delivery.yml` adds the GitHub identity provider, a role restricted to
this repository's production environment, an exact-host deployment command and
receipt writes for the existing host role. It creates no compute resources.
Install `aws/deploy-approved-release.sh` as
`/usr/local/sbin/svdex-deploy-approved-release` (root-owned, mode 755) through an
operator session. The runner can upload encrypted code archives and read small
status receipts; it cannot read backups, credentials or arbitrary command logs.
The privileged workflow actions are pinned to reviewed commits.

Configure the production environment for deployment from `main` only, without a
required reviewer. Protect main with pull requests and required source/native
checks. Set its nonsecret variables `SVDEX_DEPLOY_ROLE_ARN`,
`SVDEX_ARTIFACT_BUCKET`, `SVDEX_INSTANCE_ID`, `SVDEX_STAGING_BUCKET`. Enable the
repository variable `SVDEX_DEPLOY_ENABLED=true` only after the host helper and
AWS stack are ready. Disable that variable to stop future automated deliveries;
it does not interrupt one already running. Forks need their own infrastructure
and environment configuration; they never inherit production access.

Each delivery checks the archive digest, takes an uploads-inclusive native
backup, verifies its encrypted off-server copy, upgrades, and performs production
smoke checks. The private host log is `/var/log/svdex-github-RUN-ATTEMPT.log`.
GitHub reads a nonsensitive receipt under `deployments/github/`. A timeout means
inspect the host before retrying. A build failure restores the previous image
and configuration. Failure after migrations/theme import needs operator review;
automatic database rollback is deliberately avoided. A single-host rebuild may
briefly interrupt service. Keep isolated restore tests current, especially before
engine upgrades. Delivery never publishes policy drafts or imports local fixtures.
