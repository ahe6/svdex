# Release verification — 18 November 2026

## Current release and launch walkthrough

[PR #8](https://github.com/ahe6/svdex/pull/8) was squash-merged as
`e051b1db967cb58cdf3e074a3ff55aaa204f4155` and deployed successfully in
[production run 44213560463](https://github.com/ahe6/svdex/actions/runs/44213560463).
Source, native and responsive browser checks passed before deployment. Production
reported the same deployed revision.

A real fresh account completed the native email-code registration flow and
reached signed-in Home. Ordinary-member checks opened company/fund applications,
a People suggestion through native staff messaging, and the public offering
composer. These were cancelled without sending applications, messages or posts.
My Bids loaded its private empty state. The private offering category denied
access to the new member, while the access information page opened the external
questionnaire. Registration did not grant private access or accreditation.

The launch walkthrough found that the external questionnaire had replaced rather
than reproduced the legacy suitability questions. Version `2026-11-18-v2`
restores the legacy choice questions and financial ranges, with individual,
institution and credential branches, and keeps relationship review separate.
Four-page draft preview checks verified those branches and that optional contact
fields do not block navigation. The published responder page reports the new
version. See `deploy/discourse/investor-questionnaire.json` for exact legacy
choices and documented differences. No real or invented response was submitted.

A new uploads-inclusive native backup was copied to encrypted private storage,
downloaded and independently checksum-verified. Native restore succeeded in a
network-isolated disposable target with no published ports. Source/restored
fingerprints matched for account security/identity data, policies, category
permissions, theme fields and all four custom data tables. All nine archived
upload files matched byte checksums. Restored public pages returned successfully,
and private-category access checks passed for guest/admin roles. The test target,
its three dedicated volumes and local downloaded archive were removed; the
verified encrypted backup remains. Production data was not restored or replaced.

Private receipts, backup names and account details are excluded from the source
repository. The snapshot predates the fresh walkthrough account.

## Previous release checks (14 November)

The previous production revision was
`5acdb2039c2f182b49b06a7bca06467261da61e4`. Approved native policy topics name
Miscdex Inc, Delaware, United States as operator. Nonbinding indications,
consented public aggregates and private offering bids were explicitly enabled.
Temporary smoke-test records were rolled back; local fictional financial facts
were not imported.

## Automated clean installation

[Native CI run 43604928259](https://github.com/ahe6/svdex/actions/runs/43604928259)
passed on revision `8df2445` in 13 minutes. It built the pinned forum on a fresh
GitHub runner, installed local fixtures, migrated both plugin tables, compiled
the native themes and ran the complete permission/financial workflow suite.
Source/package checks also passed. The clean bootstrap caught and repaired
missing company fixtures, setup ordering, premature sidebar seeding and the
missing post-copy plugin migration step. Its workflow now reports all failing
suites together, rather than hiding later failures behind the first one.

## Observed checks

- Production guest/member/staff smoke checks passed: directory access, protected
  edits, posting review, tags, bookmarks/replies, private-category denials,
  canonical indication/history/withdrawal and offering-specific private bids.
- Live desktop Companies and 375px Offerings layouts were reviewed.
- Existing-owner Google login returned to the correct account. Google OAuth
  audience is now External / In production, requesting basic identity only.
- Both native test mail and an actual existing-account password-reset message
  arrived. SPF, DKIM and DMARC passed. No reset was redeemed.
- A new uploads-inclusive native backup was copied to encrypted private
  off-server storage and its archive SHA-256 verified after download.
- Native Discourse restore completed successfully in a separate container with
  no external network, no published ports and new disposable volumes. Restored
  accounts, policy topics, themes, private-category permissions and both plugin
  financial tables passed checks. All nine archived upload files matched their
  SHA-256 checksums after restoration. The disposable target was removed.

Private backup names, operational receipts, mail identifiers, account details and
configuration are intentionally excluded from this repository.

## Verification limits

Fresh native email-code registration was exercised on 18 November. Fresh-person
Google signup, redeeming a password reset, and external questionnaire submission
were not exercised in this walkthrough. Existing-account Google login and reset
email delivery were checked in the previous release. No investor identity,
accreditation or eligibility decision was simulated. Application/composer entry
checks did not send real financial submissions or publish test content.

## Repeating the recovery exercise

Use the current pinned runtime/plugin image, an uploads-inclusive native backup,
and its off-server checksum. Create a disposable container and **new** database,
log and upload volumes; use `--network none` and no published ports. Never attach
the active development or production volumes.

Initialize PostgreSQL and Redis in the disposable target, create the native
Discourse database, run the pinned migrations, and prepare writable shared paths
including `/shared/tmp/restores`. Place the backup in the native local backup
store. Enable `allow_restore` only in this disposable database, then run:

```sh
discourse restore <backup-filename>.tar.gz --location local
```

Require the native `[SUCCESS]` result, then boot the application to validate
accounts, policy content, theme records, plugin tables and restricted-category
permissions. Compare restored upload bytes against the archive, not only file
counts. Preserve a private result receipt, then delete only the named disposable
container/volumes. Remove an image only if it was created exclusively for the
exercise and is not shared with development. Recovery on a self-hosted target does not establish
compatibility or acceptance by an official managed Discourse host.
