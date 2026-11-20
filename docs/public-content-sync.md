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

1. Once catalog publishing is available, use a directory Add or Suggest changes
   button on SVDEX or open a pull request
   directly on GitHub. Both paths edit one public JSON file under
   `directory/companies`, `funds`, `people`, `products` or `securities`. Stable IDs and filenames
   remain unchanged. Public sources are required. Never commit credentials,
   account ownership, contacts collected privately, evidence documents, bids,
   interests or verification records.
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
   involved. Missing files never delete records. Product and public security
   text changes use native post revisions and preserve discussion replies.

Pre-sale campaigns use Discourse topic review. A campaign stores the topic ID of
its permanent Products entry. The read-only [public dataset](public-dataset.md)
includes guest-visible topics and their replies independently of content sync.
Add product uses GitHub when the catalog can publish reviewed files and uses
native topic review otherwise. Company, fund and person intake also keeps its
native route until hosted catalog publishing is ready.
Both Latest and All securities use the native Add offering action. All securities
lists visible Public offerings. Reviewed securities files can correct existing
public topics by topic ID. Private offerings remain in the native workflow for
authorized members.

Application workflows exclude directory-only changes from automatic deployments,
including the staging branch. Code PRs still use ordinary deployment checks. A
manual staging application preview remains available when explicitly requested.

## Enable the website's GitHub App

The private **SVDEX Directory Proposals** App is installed on `ahe6/svdex`.
Local SVDEX authenticates with that installation and has the proposal editor
enabled for signed-in members. Hosted activation and the initial catalog merge
are pending. Existing-entry edits require the corresponding file on `main`.

The directory buttons open GitHub by default. The optional in-site editor is for
signed-in members. Its only output is a public pull request. Profile ownership
and database publication use their existing workflows.

1. Register a GitHub App under the repository owner's account. Install it only
   on `ahe6/svdex`, with **Contents: write** and **Pull requests: write**. Keep
   `main` branch protection in force. GitHub grants these permissions at repository
   scope. The application writes one validated directory file on a
   `directory-proposals/` branch per PR.
2. Mount the App's private key where the Discourse process can read it. Set
   `SVDEX_CATALOG_GITHUB_PRIVATE_KEY_PATH` to that in-container path. Set
   `SVDEX_CATALOG_GITHUB_APP_ID` and `SVDEX_CATALOG_GITHUB_INSTALLATION_ID` in the
   Discourse service environment. The server creates short-lived installation
   tokens. Keep the key out of Git, theme settings and browser responses.
3. Enable `svdex_catalog_proposals_enabled` after validating the installation.
   Verify one approved test submission, then review the resulting diff. Repeat
   the submission to check that it returns the same PR. Verify permitted updates
   and stale-revision rejection. A failed request can be retried without another
   commit or PR for the same proposal.

The app and publishing workflow are separate. Keep content publishing disabled
until the independent profile backend is ready. Use a reviewed initial file
for any existing entry before offering its Suggest changes button. Products
need a catalog association to preserve their existing topic and replies.

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

Empty Funds/People/Products/Securities directories are intentional. Local invented fixtures
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
   After the corresponding hosted publishing path is verified, enable the Discourse
   setting `svdex_catalog_publishing_enabled` to expose the reviewed intake on SVDEX.
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
