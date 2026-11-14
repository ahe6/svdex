# SVDEX hosting portability — 13 November 2026

## Finding

SVDEX uses an upstream Discourse installation with a custom plugin and native
themes. It is not a core fork, a separate company database or a theme-only site. Gated nonbinding interest
and offering bids add two plugin-owned PostgreSQL tables, linked to native users and
topics. Their backend and migrations must accompany a move that retains those features.
A move to official hosting is feasible in principle, but retaining every current
feature requires the host to accept our plugin. Moving CSS to a theme does not
remove that backend requirement.

Official pricing reviewed on this date lists custom/community themes on Pro and
higher, Events on Business and higher, and unofficial/custom plugins as an
Enterprise option. Custom plugin acceptance, ongoing support and upgrade handling
must be confirmed with Discourse before committing to a hosted migration. No
hosting account, paid plan, contract or provider approval was requested here.

## Feature boundary

| Feature | Implementation | What must move |
| --- | --- | --- |
| Colors, typography, offering/company/fund layouts, responsive spacing | Native parent theme SCSS | Export/import SVDEX theme and assets |
| Cards, directories, profile summaries, filters and composer controls | Native SVDEX Interface theme component | Export/import component; backend data contract still requires plugin |
| Sidebar order, More links, full-page Chat preference and navigation labels | SVDEX Sidebar theme component | Theme component and native sidebar configuration |
| Topics, replies, tags, categories, moderation queues, bookmarks, chat, users/groups | Discourse native records | Normal database/uploads backup |
| Google login | Built-in authenticator and private native settings | Reconfigure credentials/callbacks with host; never include secrets in theme |
| Events/calendar | Official bundled Calendar/Events feature | A hosting plan supporting that feature; verify reminders and permissions |
| Company/fund profiles and directories | Native user/group records and custom fields, custom plugin controllers and serializers | Plugin approval or a separately designed native-field replacement |
| Offering figures and financial filtering | Native topic custom fields plus plugin validation, query extensions and serializers | Plugin approval; theme alone cannot enforce these rules |
| All forums tag/category directory and private-access discovery | Custom plugin client routes/controllers plus native permissions | Plugin approval or a reviewed alternative; do not expose private payloads through a theme |
| Private category membership and posting review | Native Discourse groups and category settings | Normal backup/configuration; re-test guest/member access |
| Investor-related achievements | Native badge/group records; Private Access synchronization uses the small synchronous plugin hook | Badge records plus the hook; native Workflows prototype has a tested rate-limit gap |
| About/Guidelines removal | Plugin controller extensions plus native navigation cleanup | Plugin approval; CSS hiding alone does not disable their URLs |
| Nonbinding buy/sell interest | One plugin table with canonical indications, expiry/withdrawal, aggregate-publication consent and permission-aware public sums | Plugin schema/backend; ordinary backups include the table and consent timestamp. Individual records remain private; prior private and restricted-origin records are excluded from public sums |
| Company applications | Native Companies-group membership requests with a themed structured modal | Native groups, requests and private messages; staff ownership is excluded from organization classification |
| Privacy/Terms | Native staff-editable topics and native static page settings | Normal backup/configuration and operator-approved content |
| Private-access application | External Tally questionnaire, manual staff review (older Google Form retained) | Tally ownership/sharing and responder URL; manually archive original exports into staff-only Discourse review records |
| SES, backup shipping, alarms and AWS host tooling | Self-hosting operations only | Replace with provider operations; do not run our AWS scripts on managed hosting |

## Improvements in this release

- Moved all 481 lines of custom plugin SCSS into the native SVDEX theme, before
  existing appearance adjustments to preserve cascade order. The plugin no longer
  registers a custom stylesheet. Visual changes can now be exported with the
  native theme and updated without shipping plugin CSS.
- Kept sidebar customization as an ordinary Discourse theme component, with the
  correct svdex.com metadata. Legal links appear only when native policy URLs exist.
- Preserved standard users/topics/custom fields/groups/badges instead of adding
  parallel tables or proprietary external records. Backups retain these data even
  if a destination does not yet display the custom fields.
- Guarded plugin-dependent navigation and directory redirects when the custom
  plugin is absent, so importing the theme does not register broken company/fund
  routes. This preserves a usable native forum; it does not replace those features.
- Recorded required dependencies and provider questions explicitly. A successful
  self-hosted restore does not prove acceptance by a managed host.

## Interface separation (13 November)

The offering cards, company/fund tables, profile summaries, filters, composer
controls and client route implementations now live in the native
`frontend/discourse-interface/` component. The plugin retains small
client route maps and the directory API adapter, plus its client translations and
backend implementation. No card/component/template rendering code remains in the
plugin. Native appearance and sidebar components are unchanged.

The Interface component can be exported and re-imported through Discourse's own
theme tooling. Its initializers skip SVDEX integration when the backend settings
are absent. This is a packaging boundary, not a plugin-free implementation:
company/fund routes, financial API responses and writes still need the backend.
The native route maps remain in the plugin so a theme imported on a regular forum
does not register those unsupported destinations.

Existing user/topic fields have not been renamed, duplicated or migrated. Native
user fields can replace basic scalar profile facts, but they do not replace our
numeric range filters, permission-aware related records or staff financial
validation. The installed core sorts native user-field values as strings; our
plugin instead sorts financial values numerically and keeps missing values last.
Migrating storage alone would leave these requirements and the plugin dependency
in place, so this release deliberately preserves the existing data contract.

Verification includes the source/release-package tests, native backend checks,
native theme export/import/compilation, desktop/mobile browser checks, and a
local browser check with the backend temporarily absent. The latter confirmed
that the themes retain a usable native forum and omit unsupported navigation;
company/financial features return after restoring the backend.
Develop and review locally; batch the paired plugin/theme deployment. Deploying
only the smaller plugin without the new component removes the custom interface.

## Native replacement feasibility checks (13 November)

The native Workflows badge prototype successfully grants/revokes Private Access
and reads current membership, so delayed events do not apply obsolete invitation
state. However, the installed upstream Workflows executor records saturated
executions as `rate_limited` without retrying the badge update. Default budgets
are 10 executions per workflow/minute and 20 globally/minute. Raising those
limits only moves the failure boundary. The prototype therefore is not an exact
replacement for the reliable synchronous membership hook. The existing hook is
retained. No production workflow or feature-setting change is included.

The temporary local graph used for UI review has been removed, and the Workflows
feature is restored to its original disabled state. Its graph builder is in
`deploy/discourse/prototypes/private-access-workflow.rb`, outside the runtime
plugin and release package. The local verification publishes isolated graphs
inside a rollback, exercises the native executor and rate-limiter boundary, and
cleans up its accounts, badge grants, graph records, settings and dependency cache.
No external credentials, code nodes, network requests or membership grants are
required by the native graph itself.

A separate rollback-only company-field prototype verified native staff-only
editing, public profile/directory display and group-filtered counts. Native text
fields sort 100 before 9 and accept non-numeric financial input. Existing company
fields and values therefore remain in their current backend contract. No duplicate
field schema or production data migration was added. Basic scalar facts are viable
native-field candidates if a later migration has a concrete benefit. Numeric
queries, financial validation and related-record aggregation stay server-side.
Native new-account profile hiding also differs from our selective organization
profile exception; migration must preserve that distinction.

The offering split and Updates use native categories, tag groups and topics.
The small server event hooks synchronize public/private visibility tags after
creation, review approval, edits and category moves. Exemption labels use native
staff-only tag-group permissions. Profile update timelines are permission-aware
native-topic queries. These add no custom storage tables, but their automatic
behavior and query hooks still require host-supported server customization.

These checks support reducing unnecessary plugin presentation code without
forcing stateful behavior into themes or replacing reliable hooks with a more
complicated automation that loses updates. Both feasibility checks are part of
`npm run check:discourse` and leave no operational prototype active.

## Migration procedure

1. Give the host the custom plugin source and the feature boundary above. Obtain
   explicit acceptance and a supported Discourse version before buying a migration.
2. Export all three native theme/component archives (appearance, Sidebar and Interface), a database/uploads backup, native site
   settings and a manifest of required official plugins. Keep credentials private.
3. Restore on isolated staging with outbound mail disabled. Install the supported
   plugin/theme versions before inspecting company/offering fields.
4. Re-test guest/member/staff permissions, direct private URLs, member removal,
   review queues, company/fund search, financial edits/validation, filtering,
   native policy pages, Google account linking, Events RSVP/reminders and Chat.
5. Reconfigure Google credentials, email, domain, backups and provider-specific
   settings. Update the Privacy Policy's provider/hosting description to match
   the actual destination. Tally and older Google Forms responses require their own access and
   retention management; they do not appear in a forum backup.
6. Verify rollback and mail delivery before DNS cutover. Preserve the old host
   until the restored site and uploads are accepted.

If we later want a standard hosted plan without any custom plugin, that is a
separate product/engineering project. Native profile fields can hold some company
facts and native topic bodies/tags can hold offering information, but the current
numeric sorting, custom directory endpoints, financial write validation and
private-aware discovery would need replacements. Do not silently discard them
or move permission checks into browser JavaScript to claim theme-only support.

Sources checked: [official pricing and hosting FAQ](https://www.discourse.org/pricing),
[official plugin directory](https://www.discourse.org/plugins),
[official migration information](https://www.discourse.org/migrations).


## Maintenance cleanup (14 November)

Presentation remains in the native themes; permission enforcement and financial
storage remain in the plugin. Interface registration is now split by feature,
and the two Overview routes share a directory component. Common financial
validation/visibility lives in `FinancialSubmissions`. Interest and offering bids
remain separate tables and workflows, both included in native backups. The owner
management view remains private and uses the existing records.

Reviewed native source contracts now flag upstream changes to the classes we
extend, and verify the copied Chat shell against its native source. See
[maintenance](discourse-maintenance.md) for the review/update procedure. This
helps self-hosted upgrades; it does not establish managed-host plugin acceptance.
