# Release verification — 14 November 2026

## Deployed release

Production received source revision `5acdb2039c2f182b49b06a7bca06467261da61e4`.
A preserving paired plugin/theme upgrade completed, with runtime source hashes
and 73 database theme source files checked against the release. Follow-up
commits repair fresh contributor setup and refresh the verifier copied by future
upgrades; they do not change the deployed product interface or financial logic.

The approved Privacy/Terms text was published through native policy topics with
Miscdex Inc, Delaware, United States as operator. Nonbinding indication intake,
consented public aggregates and private offering bids were enabled explicitly.
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

Existing-account Google login and native workflow tests do not establish a real
new person's complete signup experience. A fresh-person browser signup and an
external questionnaire submission were not performed in this release check.
No investor identity, accreditation or eligibility decision was simulated.

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
container/volumes/image. Recovery on a self-hosted target does not establish
compatibility or acceptance by an official managed Discourse host.
