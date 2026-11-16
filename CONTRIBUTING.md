# Contributing to SVDEX

## Start here

SVDEX customizes upstream Discourse using native themes and a server plugin.
Read [product scope](docs/product.md) and
[maintenance boundaries](docs/discourse-maintenance.md) before a larger change.
Work locally; contributors do not need production or cloud access.

1. Create a branch from `main`.
2. Follow the [README setup](README.md#develop-locally).
3. Make a focused change. Put presentation in the native themes and enforce
   validation, ownership and permissions on the server.
4. Run the checks below and open a pull request describing the problem, resulting
   behavior, validation and any deployment/settings implications.

This software uses GPL v2 or later. New original contributions should use that
license. Preserve third-party notices and identify copied/adapted upstream code;
do not import material whose redistribution rights are unknown. No CLA or
separate signing service is required by this contribution workflow.

## Choosing work

Useful first contributions include documentation corrections, reproducible UI
bugs and improvements to an existing filter or native component integration.
For product features or changes to financial/access rules, discuss the scope
first. Prefer improving an existing native behavior over introducing another
framework, data store or parallel account system.

Product screenshots should use local data. Existing production content is not a
test fixture. Do not add “demo” or similar labels to the product UI; keep fixture
identification in setup/test code. Do not copy local financial figures into a
production release.

## Verification

```sh
npm run check
scripts/discourse-local.sh appearance
npm run check:discourse
```

The last command requires a running, configured local forum and its local company/
fund fixtures. It checks native permissions, moderation, filters, financial
records, theme compilation/export/import and the pinned upstream contracts.
Tests roll back their own records; avoid concurrent browser review while these
checks temporarily import themes or toggle settings.

### Finding the right file

| Change | Start here |
| --- | --- |
| Spacing, typography, responsive behavior | `frontend/discourse-appearance/styles/` and its ordered `styles.json` |
| Offering search/autocomplete/count | Interface `components/svdex-offering-search.gjs` |
| Offering screening controls | Interface `components/svdex-tag-group-filters.gjs` |
| Home/Discussions/Event tabs | Interface `integrations/svdex-discovery-tabs.gjs` |
| Native labels and Chat entry behavior | Interface `api-initializers/svdex-native-navigation.gjs` |
| Sidebar destinations/order | Sidebar `api-initializers/svdex-sidebar.gjs` |
| Secured topic filtering/counts | Plugin `lib/discourse_svdex/topic_discovery.rb` |
| Shared non-secret feature defaults | `deploy/discourse/native-defaults.rb` |

After editing styles, run `npm run build:styles` and include the generated
`common.scss` in the PR. The manifest preserves cascade order; grouping files is
not permission to reorder selectors. The appearance installer builds it for local
review, and checks/release packaging reject stale output. Production Discourse
still receives a normal single stylesheet and has no extra runtime build step.

For a theme change, review desktop and 320px/375px mobile layouts, empty/populated
states, and ordinary native views affected by shared styles. Include screenshots
in the PR. For backend changes, exercise guest/member/staff access and include
negative cases, especially other users' records or inaccessible private topics.
Do not submit real bids, questionnaire answers or verification documents to test.

GitHub runs source/package checks and a fresh native Discourse build for public
Interface/plugin pull requests. Native checks can also be started manually.
Maintainers should inspect both results before merging.
Upstream-contract failures require reviewing the changed native implementation,
not merely replacing its stored hash.
Native scenarios must create extra participants inside their rollback scope;
visual-review accounts on a developer's machine are not test prerequisites.

## Remote/cloud development

A dedicated Linux machine with Docker can use the same scripts. The forum and
Mailpit bind to loopback. Forward ports 4080/4081 privately using your editor's
remote feature or SSH; keep cloud/editor forwarded ports private. Never expose
an unreviewed local administrator or captured mail to the Internet. Use a separate
Docker host/volumes per developer: container names and ports are fixed.

There is no requirement for AWS, Cloudflare, live OAuth credentials, a shared
development database or a paid hosted workspace. Actual Codespaces/devcontainer
bootstrap is not yet provided or verified. Discuss those
separately rather than assuming this is a one-click cloud environment.

## Reporting

Use public issues for reproducible, nonsensitive bugs or proposals. For private
financial data, credentials, account details or exploitable vulnerabilities, use
[SECURITY.md](SECURITY.md). Never attach production backups, `.data/`, `.env`,
mail captures, investor documents or unredacted private responses to an issue.

## Source releases and production deployment

`npm run package:source -- artifacts/svdex-source.tar.gz` packages a clean Git
revision and writes its commit/checksum sidecar. It archives committed files, not
the working directory; ignored local secrets/data never belong in a release.
Uncommitted tracked or untracked source makes the command fail before writing.

The manual **Validate source release candidate** workflow runs the reusable fresh
Discourse job, then retains a source archive/checksum as a short-lived Actions
artifact. It does not create a GitHub release, change repository visibility or
deploy a site. No production secrets are provided to contributor workflows.

Maintainers push trusted candidates to `staging` for an automatic isolated preview,
review it, then merge the same source into `main`. **Deliver SVDEX production**
requires successful staging verification and native checks, then deploys without
another approval click. Contributor pull requests never receive either server's
identity. No AWS access is needed to contribute or run native checks.

Maintainers deploy paired plugin/themes using the preserving production upgrade
in [production operations](deploy/discourse/PRODUCTION.md). A public source
archive is not a configured production bundle. Production scripts currently
protect the SVDEX host specifically; forks need their own reviewed hostname,
operator/policies, contact/form destinations, email and secrets. Do not weaken
those guards or point a fork at SVDEX's production accounts to simplify setup.
