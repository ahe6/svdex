# Your first contribution

## Get a working site

Fork the repository, clone your fork, and create a branch from current `main`.
Use a dedicated Docker host per checkout. You need Node 24+, Git, Docker, Ruby,
Python 3 and Bash; the Discourse application itself runs inside Docker.

If you use nvm, `nvm use` selects the repository's `.nvmrc` version.

```sh
npm run doctor
npm ci
npm run setup
```

The first setup builds the pinned Discourse version and creates local content.
It can take tens of minutes. Open <http://localhost:4080>; the generated local
administrator credentials are in `.data/discourse-local-admin.json`. Captured
mail is at <http://localhost:4081>. Keep both ports private. No SVDEX account,
AWS access, production backup or paid service is needed.

For later sessions use `npm start`. Repeated setup preserves data, but it is much
slower than importing the part you changed. There is no automatic hot reload.

## Make a small UI change

1. Find the native component in `frontend/discourse-interface/` or the relevant
   style file in `frontend/discourse-appearance/styles/`.
2. Edit the source. Prefer native Discourse components, spacing and typography.
3. For Interface/Sidebar edits, run `npm run sync:themes`. For styles, run
   `npm run sync:styles` (also imports Interface/Sidebar and branding).
4. Reload the browser. Review desktop and narrow mobile widths, long names,
   empty/populated states and any native screens sharing the styles. Check the
   browser console: successful compilation does not catch every boot-order error.
5. Run `npm run check` and include screenshots in your PR. Style imports regenerate
   `common.scss`; commit it with its source files.

Do not rerun setup or reset the database for a spacing change.

## Change backend behavior

The plugin under `deploy/discourse/plugins/discourse-svdex/` owns authorization,
validation, records and migrations. Themes own presentation. Keep permission
checks on the server; hiding a button does not restrict its API.

For a complete local plugin update, use `npm run sync:plugin`. It copies the
plugin, migrates, compiles its assets and restarts the local app. It also reapplies
local offering configuration and imports Interface/Sidebar, so finish browser
review before running it. Ruby-only quick edits can use the narrower procedure
in [operations](operations.md#updating-code).

Use focused checks during development:

```sh
npm run check:discourse -- --list
npm run check:discourse -- people-facts
npm run check:discourse -- offering-bids private-offerings
```

Names come from `--list`; arbitrary script paths are not accepted. A focused pass
is not a full-suite pass. Before review of backend/shared behavior run
`npm run check:discourse` with no arguments. PR/release CI still runs the full
suite. Do not use the browser during native checks: some temporarily import
themes or toggle settings. Test guest/member/staff behavior, including denial of
other users' records and inaccessible private topics.

## Reuse community work

Look for an existing Discourse setting, component, plugin or theme before adding
a parallel system. Propose new dependencies in an issue/PR with their source,
license, maintenance status, version and required permissions. Verify compatibility
with our pinned Discourse version in your local installation. A dependency that
works with upstream's newest release may not work with ours.

Keep copied code's attribution and license. Original contributions use GPL v2 or
later. Follow [maintenance boundaries](discourse-maintenance.md) for choosing a
theme versus plugin and reviewing upstream upgrades. Add dependencies explicitly
to the appropriate installer/configuration; clicking Install only in your local
admin UI does not make them reproducible for other contributors or deployment.

## Open a PR

Describe the concrete problem, final behavior and validation. Include permission
cases, migration/settings implications, screenshots or manual steps as relevant.
Never attach credentials, captured mail, financial submissions, `.data/` or
production exports. A maintainer may need to approve a first-time fork's CI run.
Contributor jobs have no deployment identity; only trusted staging/main workflows
can access the corresponding SVDEX deployment environment.

Maintainers review on staging before merging the same source into main. You do
not need staging access to contribute. Do not push a public PR's code to staging
before it has been reviewed, and never put cloud credentials into a fork.

## If setup fails

- Docker cannot connect: start Docker Desktop/Engine and rerun `npm run doctor`.
- Port 4080/4081 or a named container is already in use: use the existing checkout
  or a dedicated Docker host. Do not delete another developer's containers/data.
- Build or startup failed: use `scripts/discourse-local.sh logs` locally and
  `npm run status`; redact logs before sharing them publicly.
- Docker ran out of memory or disk during compilation: increase its allocation
  or use a dedicated remote Linux host. This is a full Discourse build.
- An edit is absent: run its import command and reload. Plugin client routes need
  `npm run sync:plugin`; source changes are not automatically mounted into Rails.
- Need cloud development: use the private SSH/editor forwarding instructions in
  [operations](operations.md#remote-linux-development). Codespaces/devcontainer
  provisioning is not currently supplied or validated.
