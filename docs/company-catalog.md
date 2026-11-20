# Reviewed company files and site corrections

Independent Companies profiles are available locally. The shared importer also
handles Funds, People and Products. See [current rollout status](public-content-sync.md).

The public data file is the source for the fields it contains. Discourse's database
serves the existing searchable directory/profile and holds account links, logos,
publication controls, interest and discovery records independently. There is no
background two-way database/Git synchronization.

| Information | Authority |
| --- | --- |
| Name, summary, sector, company tag, stage, location, sourced financial facts | Reviewed company JSON file |
| Login/official account link, logo upload, publication state | Database and staff controls |
| Interest, bids, private correction messages, discovery review/audit | Existing private operational storage |

The generated public-download snapshots are outputs, not the input catalog; changes
should be proposed in these reviewed files rather than in a generated export.

The first file is `directory/companies/svdex.json`. Its financial figures are
unspecified. It does not turn the old local financing examples into sourced data.
The stable public ID is separate from the database row ID and any account name.

## Local import

Install the current plugin code locally and stop the UI watcher. The shared
importer reads reviewed files from `directory/`.

```sh
npm run dev:stop
bash scripts/import-public-catalog-local.sh          # preview only
bash scripts/import-public-catalog-local.sh --apply  # explicit local import
npm run dev
```

The runner refuses hosts other than localhost:4080. Offline validation rejects
unknown fields, duplicate JSON keys, unsupported versions, malformed URLs/dates,
ambiguous amounts and missing evidence for known financial figures. Native import
also resolves tags and validates stage/location against the site's existing rules.

Imports are transactional and content-addressed. Repeating the same content does
not rewrite rows. A batch conflict rolls back the whole batch, including inside an
existing transaction. Missing files do not delete profiles. New reviewed records
are listed. File changes never grant account control or private-offering access.
Logos, operational links and existing interest/discovery relationships are preserved.
Unreviewed changes to file-owned database fields block imports instead of being
silently overwritten. The old staff editor cannot edit those managed fields;
operational account-link maintenance remains available.

## Site contribution

**Suggest changes** now opens a public GitHub proposal for file-managed
profiles. Follow the [shared directory workflow](public-content-sync.md).
The older private review threads remain available to staff for exporting
corrections already submitted.

## Earlier private correction intake

1. A signed-in contributor opens **Suggest changes** on the company profile.
2. Like native membership requests, this fixed-recipient intake accepts brand-new
   active accounts without enabling general private messaging. The form records proposed fields and evidence in a native private-message topic
   accessible to the contributor and configured staff reviewer. Free-text evidence
   may describe other requested changes for staff to translate into the file.
3. Staff review the sources and prepare a candidate file:

   ```sh
   npm run dev:stop
   bash scripts/export-company-correction-local.sh TOPIC_ID
   ```

   This writes `work/company-corrections/TOPIC_ID.json`; it does not modify the
   catalog, submit a PR, publish facts or expose the private review thread.
4. Staff review and adjust the candidate, then copy approved changes into the
   corresponding `directory/companies/ID.json` and make the ordinary reviewed PR.
   Export again against the current revision before applying an older proposal.
5. After review, preview and explicitly import the approved files. Staff can close
   the original review thread through Discourse's normal UI.

Export requires staff access and checks the proposal's base revision. A stale form
cannot submit against a newer imported revision; a stale proposal cannot be exported
without reconciliation. Individual corrections are not part of the public dataset.


## Remaining work before a production rollout

- Promote the independent profile backend and test the reviewed import on staging.
- Establish a stable public-data licensing policy.
- Source/reviewer conventions, representative claims and creation/publication UI.
- Production-scale query/index design; the current local directory remains bounded.

The correction path reuses Discourse accounts, private topics and backups. It does
not create a separate submissions service or a second private database.


## Validation of this slice

56 source/package tests and the focused native company-catalog, independent-company
and interface-theme groups passed. The catalog checks exercise new-account intake,
private review visibility, source ownership, exact public-data validation, idempotent
imports, stale revisions, preserved operational links and rollback of invalid batches.
Browser review covered the desktop/375px form, optional financial fields and a real
local correction topic; staff export prepared its candidate file without changing
approved facts. Preview and apply were exercised locally for the initial catalog,
then re-import was checked for no changes. The full 36-group release suite was not
rerun for this local experiment.
