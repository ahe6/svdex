# Reviewed public content, without an application deployment

## Status

The file validator, data bundle, database importer and GitHub delivery workflow
are prepared. The importer is tested against the **local independent profiles**.
No new AWS role or SSM document has been installed, no GitHub publishing variable
has been enabled, and no production content has changed in this work.

Production still uses the older account-backed directories. Its backend does not
load the independent-profile catalog runtime. The runner deliberately refuses
that installation. Release/promote the independent profile backend and its schema
before enabling hosted synchronization; the content job does not create tables,
install a plugin, convert accounts or turn on prototype routes. Do not bypass
this readiness check to make a workflow green.

## Contribution flow

1. Edit one public JSON file under `directory/companies`, `funds`, `people` or
   `products`. Stable IDs and filenames remain unchanged. Public sources are
   required. Never commit credentials, account ownership, contacts collected
   privately, evidence documents, bids, interests or verification records.
2. CI validates the entire public bundle. A maintainer reviews and merges the PR.
   The content workflow rejects direct pushes and stale main revisions. It accepts
   an approving writing-maintainer review, or the sole owner's explicit merge.
   CODEOWNERS requests review; it does not itself enforce peer approval. The
   current repository requires source/native checks, with no required peer review.
3. Once enabled, a separate `content` GitHub environment uses temporary AWS access
   to upload **only public JSON**. A fixed SSM document calls the installed host
   importer. It cannot deliver executable application files or read backups.
4. The backend validates again, serializes imports and updates owned fact fields
   in one transaction. The running pages read those database records on their
   next load. No front-end build, service restart or cache-busting deployment is
   involved. Missing files never delete records. Product changes use native post
   revisions and preserve discussion replies.

Application workflows exclude directory-only changes from automatic deployments,
including the staging branch. Code PRs still use ordinary deployment checks. A
manual staging application preview remains available when explicitly requested.

## File ownership and rollback

Company v1 files retain their existing format. Other entity types use the format
in [directory/README.md](../directory/README.md). Imports own only named public
facts, names and summaries. Logos, account links, discovery provenance, affiliations
and private financial records remain operational data; this workflow does not
silently take them over. File-owned profile facts cannot be overwritten through
the profile editor; account links remain editable by staff. Company corrections
can still arrive in the native private staff inbox before a reviewed file change.

The stored revision and imported snapshot detect later database edits. A conflict
aborts the entire batch, rather than choosing a winner automatically. Reconcile
those changes into a reviewed file before retrying. To undo a published correction,
revert its data-file commit through the same review process. Native product edit
history, staff action logs and normal private backups complement Git history.
GitHub files are not a substitute for private database/uploads backups.

## Local commands

Stop the UI watcher before imports or native tests:

```sh
npm run dev:stop
ruby scripts/build-public-catalog.rb
bash scripts/import-public-catalog-local.sh          # transactional preview
bash scripts/import-public-catalog-local.sh --apply  # reviewed current files
npm run check:discourse -- public-catalog company-catalog independent-entities
npm run dev
```

Empty Funds/People/Products directories are intentional. Local invented fixtures
must not become public catalog files or be bundled for production.

## Hosted activation, after backend promotion

1. Release the independent profile backend/schema and installed
   `import-public-catalog.rb`. Verify a harmless import on closed staging, then
   verify the corresponding application release before production activation.
2. Install reviewed `aws/sync-public-catalog.sh` as
   `/usr/local/sbin/svdex-sync-public-catalog`. Create root-owned mode-0600
   `/etc/svdex-catalog.env` with `SVDEX_CATALOG_BUCKET` (the existing private
   artifact bucket) and `SVDEX_CATALOG_HOSTNAME` (`staging.svdex.com` or `svdex.com`).
3. Review and apply `aws/content-sync.yml` using the existing OIDC provider,
   exact repository/owner numeric subject IDs, one target instance and host role.
   This is a new narrow GitHub production capability and needs explicit access
   approval before provisioning. No broad shell-command or backup permissions.
4. Restrict the GitHub `content` environment to main. Configure its
   `SVDEX_CONTENT_ROLE_ARN`, `SVDEX_CONTENT_BUCKET` and `SVDEX_CONTENT_INSTANCE_ID`.
   Set repository variable `SVDEX_CONTENT_SYNC_ENABLED=true` only after an actual
   staged end-to-end JSON delivery/import/receipt check.
5. A main-branch reviewed merge touching a data file triggers automatic sync.
   Public CI receives only commit/checksum/run/status, while detailed import logs
   stay on the host. Both deployments and content sync use the same host lock.

The hosted delivery path is prepared, **not yet verified end-to-end in AWS**.

## Validation recorded 2026-11-19

62 source/unit tests passed. Focused native groups passed: public-catalog,
company-catalog, independent-entities, interest-verification, public-interest and
my-interest. The new catalog group exercises dry-run isolation, all new entity
types, no manufactured accounts, idempotence, native product revisions/replies,
source reversion, full-batch conflicts and non-deletion. CloudFormation accepted
the optional content-sync template in a validate-only request; no stack was
created. Browser review covered the combined interest form, direction changes,
neutral product control dimensions at 320px/375px, and individual profile layouts.
The prepared browser CI cases were not run through the local command line.
The actual local repository-bundle preview also passed, reporting one existing
company record and zero changes.
