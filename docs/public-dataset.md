# Downloadable public dataset

The separate public repository [ahe6/svdex-data](https://github.com/ahe6/svdex-data)
owns the guest-only exporter, SQLite loader, privacy regression tests, format
documentation and daily publishing workflow. It reads the deployed public JSON
endpoints. It has no AWS access, login session, API key, database connection or
ability to change the SVDEX application. Application releases do not depend on it.
It queries Discourse's guest topic filter independently of the site's feeds,
which keeps past public events in the export. Related pre-sales include a product
topic ID when the linked product is also public and in the snapshot.

Daily output lives in a replaceable **latest GitHub Release**, not Git history.
The manifest points to versioned gzip JSON Lines files and contains checksums,
row counts and the observation window. Current public categories, tags, topic
metadata, offering/product/pre-sale facts, current posts/replies, curated profiles
and author attribution are exported with explicit field allowlists. Attachments
remain public links; binary uploads, raw revisions, private material and financial
submission records are not mirrored. Missing/hidden profile facts are not inferred
from account identity. The publisher fails on known pagination or stream gaps.

Guest authorization and export selection are both enforced. The export must never
be made by sanitizing a native database backup. Restricted/private/unlisted/deleted
topics, hidden/deleted posts, whispers and private messages are excluded. The
snapshot deliberately omits even public interest aggregates in schema v1; it never
serializes indication or bid tables. Source code changes that add fields need
privacy regression tests in the data repository.

The load command verifies a downloaded snapshot and atomically replaces a dedicated
local SQLite database. It is a research/development dataset, **not a Discourse
restore**: accounts, passwords, permissions, private content and original upload
bytes cannot be recovered from it. Continue encrypted native backup shipping and
isolated restore checks independently. Do not create impersonation-ready accounts
or copy public posts back into production using this dataset.

The removal file lists IDs absent since the immediately previous snapshot. Clients
that skip snapshots must fully replace their local tables. Only the current public
download is intentionally retained, and superseded payloads are removed after
verifying the replacement. Downloads already held by other people cannot be
recalled. Because API collection spans requests, this is not an atomic database
snapshot; record the observation window rather than claiming exact consistency.

The operator approved a public Privacy Policy revision on 18 November 2026 describing
the dataset and the restored questionnaire. That exact Privacy Policy was published
through a native policy-post revision; Terms were left unchanged. User content
retains its original rights; GPL applies to the software, not automatically to data.

## Verify a publication

Follow the data repository README to download the latest manifest and payloads,
verify them and load SQLite. Confirm that restricted category IDs are absent and
that the source is `https://svdex.com`, never a local-fixture origin. The release
workflow independently downloads its publication and verifies checksums before
removing old assets. A failed job leaves the last usable manifest in place unless
it failed after the manifest swap; check the run and current public download.
Investigate a failed daily run before claiming the snapshot is current.

If private content is suspected, stop the data publishing workflow and remove the
affected public assets immediately; preserve a private incident receipt and assess
downstream copies. Do not paste the leaked content into a public issue. The data
workflow has no credentials that can weaken site access controls.
