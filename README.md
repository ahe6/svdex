# SVDEX

SVDEX is a company/fund/product directory and offering/discussion interface built on
Discourse. This repository contains the native themes, server plugin, local
Docker tooling and self-hosted deployment scripts. Company/fund profiles use
native accounts; offerings and updates use native topics. Individual interest
and bids remain private financial records.

## Develop locally

Install Git, Docker (Docker Desktop on macOS) and Node.js 24 or later. Ruby,
Python 3 and Bash are needed for the source/tooling checks; the actual Discourse
application and its compiler run inside Docker.

```sh
npm ci
npm run setup
npm start
npm run status
```

The site is at <http://localhost:4080>; captured development mail is at
<http://localhost:4081>. No AWS, Google or production credentials are required.
Setup builds the pinned upstream Discourse version and can take some time. It
creates a local administrator; credentials are in the ignored private file
`.data/discourse-local-admin.json`, not in terminal output or source control.

Docker volumes hold the database/uploads; `.data/` holds private local tooling.
Repeated setup preserves the administrator and existing data. For ordinary code
edits, use the smaller update commands instead of rerunning setup:

```sh
scripts/discourse-local.sh theme       # Sidebar + Interface components
npm run build:styles                  # after editing appearance/styles/
scripts/discourse-local.sh appearance  # builds styles + installs native themes
npm run check                         # source and package tests
npm run check:discourse                # real local Discourse workflow checks
```

Backend changes require copying/reloading the plugin; new plugin client routes
also need asset compilation. See [maintenance](docs/discourse-maintenance.md)
and [operations](docs/operations.md). Local commands never deploy the live site.

## Where things live

| Area | Source |
| --- | --- |
| Frontend components and native integrations | `frontend/discourse-interface/` |
| Sidebar navigation | `frontend/discourse-sidebar/` |
| Appearance and branding | `frontend/discourse-appearance/`, `assets/brand/` |
| Server plugin and migrations | `deploy/discourse/plugins/discourse-svdex/` |
| Local setup, native checks and deployment | `scripts/`, `deploy/discourse/` |

Start with [contributing](CONTRIBUTING.md) for a first change, or the
[documentation index](docs/README.md) for product, engineering and deployment.
[Report sensitive security problems privately](SECURITY.md).

GitHub runs lightweight source checks plus a fresh native Discourse build for
public Interface/plugin pull requests. A manual source-release validation workflow
reuses the fresh native job and packages checked, committed source only. The native job compiles Glimmer/SCSS and
runs server workflow checks; it can also be started manually. Neither job has
production deployment credentials. Relevant updates merged to `main` also run
the **Deliver SVDEX production** workflow, which requires a successful matching staging preview
and deploys merged code automatically using temporary, narrowly scoped AWS access. See
[production operations](deploy/discourse/PRODUCTION.md#github-delivery).

## Licensing and publication

Original SVDEX software is **GPL v2 or later**; see [LICENSE](LICENSE),
[COPYRIGHT.md](COPYRIGHT.md) and [third-party notices](THIRD_PARTY_NOTICES.md).
Third-party materials retain their own terms. This repository contains active
SVDEX source only; deployment secrets, historical research captures, investor
responses, database exports and the retired standalone app are not included.
