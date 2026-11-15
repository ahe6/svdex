# Local and remote development

## Local runtime

Use `npm run setup` for an initial installation and `npm start` to start the
existing forum/mail containers. `npm run stop`, `npm run status` and
`scripts/discourse-local.sh logs` operate on that same local instance. The forum
binds to localhost:4080 and Mailpit to localhost:4081. Development email is
captured, not relayed. Native login works without production OAuth credentials.

The upstream Docker checkout and private administrator credentials live in
ignored `.data/`. Forum/uploads/log/mail data live in named Docker volumes.
Setup pins Discourse and discourse_docker to reviewed revisions; source checks
keep those aligned with production configuration and upstream contracts.
Changing the config pin does not rebuild an already running instance.

Do not reset the database or delete volumes to apply a theme change. Fixture and
configuration commands are local-only, not production release operations.

## Updating code

| Change | Local command or procedure |
| --- | --- |
| Interface/Sidebar | `scripts/discourse-local.sh theme` |
| Parent theme, branding and components | `scripts/discourse-local.sh appearance` |
| Ruby backend only | Copy `deploy/discourse/plugins/discourse-svdex/.` to the matching local plugin directory, then restart Unicorn |
| Plugin client route declarations | Use `scripts/discourse-local.sh listings` to compile plugin/application assets; this also reapplies local offering configuration |
| Local company/fund fixture accounts | `scripts/discourse-local.sh companies` |
| Reviewed marketplace structure | `scripts/discourse-local.sh marketplace` |
| Local example topics and private interest/bid activity | `scripts/discourse-local.sh fixtures` |
| Local Chat/Events/Achievements | Corresponding `chat`, `events`, `achievements` commands |

For a Ruby-only update from the repository root:

```sh
docker cp deploy/discourse/plugins/discourse-svdex/. miscdex-forum:/var/www/discourse/plugins/discourse-svdex/
docker exec miscdex-forum sv restart unicorn
```

The `listings` command is broader than a hot reload: it can reapply native local
category settings. Do not use it unnecessarily during ordinary theme work.

## Verification

```sh
npm run check
scripts/discourse-local.sh appearance
npm run check:discourse
```

The source/package check needs Node, Ruby, Python and Bash. The native check uses
the installed local Discourse and its fixture accounts to exercise permissions,
moderation, directories, financial records, theme compilation/export/import and
upstream contracts. It rolls back its own test records and restores temporary
settings. Do not review the browser concurrently with native theme/flag tests.
Review affected desktop/mobile screens afterward.

The source workflow runs lightweight checks. `native-discourse.yml` builds a
fresh pinned forum and runs the native suite for public contribution PRs and
manual runs. It uses isolated GitHub runners without deployment credentials.
A local test pass is separate from the native CI result.

## Remote Linux development

Use the same pinned Docker setup on a dedicated Linux machine. No cloud account
is required for local development. For a remote machine, forward loopback ports
4080/4081 privately through SSH or an editor remote connection. Keep forwarded
ports private; the captured mail and generated local administrator are sensitive.
Do not open them with a public security-group rule or public tunnel.

Each developer needs an isolated Docker host/volumes because the current tooling
uses fixed container names and ports. Shared multi-tenant development, a
Codespaces/devcontainer bootstrap has not been implemented or verified.
Native CI uses a separate disposable GitHub runner for each run. No extra development host is provisioned by these scripts.

## Production

[Production operations](../deploy/discourse/PRODUCTION.md) describes packaging,
paired theme/plugin upgrades, policy publishing, feature flags and verification.
Local commands never deploy. AWS sign-in and live inspection are separate from
local source checks. Contributors do not need access to production accounts,
financial data, cloud credentials or external questionnaire responses.
