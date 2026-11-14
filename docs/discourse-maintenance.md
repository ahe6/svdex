# Discourse maintenance

## Runtime boundaries

- `frontend/discourse-interface/`: client components, templates, controllers and
  routes. The initializer only checks that the backend is present and registers
  the feature integrations below.
- `frontend/discourse-sidebar/`: native sidebar links, ordering and navigation.
- `frontend/discourse-appearance/`: layout and appearance within the native theme.
- `deploy/discourse/plugins/discourse-svdex/`: permission-aware data queries,
  serializers, validation, financial records, hooks and client route declarations.
  This remains a custom-plugin installation, not a theme-only site.

The Interface integrations are grouped under `javascripts/discourse/integrations/`:

| Module | Responsibility |
| --- | --- |
| Discovery navigation | Native breadcrumbs, tag/filter navigation, Chat shell and discovery controls |
| Private access | Public onboarding choices and notice; never private topic authorization |
| Organization profiles | Company membership requests, directory choices and summary selection |
| Topic metadata | Compact category names and native tag color markers |
| Offering topics | Composer/first-post details, review details, topic rows and financial column |

Registration stays centralized and plugin-guarded. Components perform rendering;
server controllers remain authoritative. Both Overview routes use the shared
`svdex-overview-directory` component, while their controllers choose their own
secured category sets. Ordinary native user and discussion views remain native.

`FinancialSubmissions` owns exact USD-cent parsing, active organization and
visible-offering checks, issuer matching for bids/history, and record state.
Indication and bid controllers retain their different consent rules, ownership,
expiry and aggregation behavior. Legacy offering-linked interest retains its
explicit company-tag validation; it shares the hidden/deleted-topic rejection.
Do not merge interest and bids merely because they share form controls.

## Local verification

```sh
npm run check
bash scripts/discourse-local.sh appearance
npm run check:discourse
```

The appearance command imports Sidebar and Interface before the parent theme.
It does not install new backend files. For Ruby-only plugin changes, copy the
plugin into the local container and restart Unicorn. New plugin client route
maps require rebuilding the plugin JavaScript and application assets as well.
Use the preserving production upgrade for a release, not local setup commands.

Run native checks after theme import and before the browser review. Native checks
include theme export/import and temporarily change feature flags in isolated
runners; concurrent UI review can therefore show transient state. Financial and
permission checks roll back their records and restore settings. Temporary UI
records should likewise be scoped and removed after review.

## Discourse upgrades

`deploy/discourse/upstream-contracts.json` records the reviewed native source
hashes for the components/routes/controllers we extend. The native suite fails
when those sources change or disappear. These conservative checks request review;
they do not prove semantic compatibility on their own.

On an upstream change:

1. Compare the changed native implementation with its named SVDEX integration.
2. Update our extension only as needed. The copied Chat shell should differ from
   native only by its Discussions navigation import and insertion.
3. Review and update the affected source hash and the recorded Discourse revision.
   Do not regenerate hashes merely to turn a failing check green.
4. Run source/native checks and desktop/mobile review of affected routes,
   including guest/member/staff permissions and plugin-absent behavior if relevant.

Checks read local Discourse sources; they need no remote fetch or credentials.
Add a contract entry when introducing another native class override or copied
shell. Prefer supported outlets and value transformers over copying templates.

## Releasing

See [production operations](../deploy/discourse/PRODUCTION.md). Commit paired
plugin/theme changes together, deploy a reviewed source revision, and keep
financial intake flags separate from presentation release. Native users, groups,
topics, fields, indications and bids all belong to ordinary Discourse backups;
there is no separate browser or external database to maintain for this feature.
