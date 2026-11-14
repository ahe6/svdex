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
