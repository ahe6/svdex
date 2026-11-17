# Company and fund accounts

Companies and Funds use the same permission-aware native user directory, with
separate sidebar destinations. Organization accounts belong to the configured
Companies group; individual fund vehicles also belong to the configured Funds
group. A fund manager is not automatically a fund vehicle. Native Users stays
unchanged. Account activity and achievements retain core behavior.

Staff edit disclosures under the account's native admin details. Company columns
are Sector, Last valuation, Total funding, Location, Key People and Open offerings.
Stage is retained on profiles and in filters. Fund columns are Strategy & Focus,
Location, Fund size, Fund Life, Key People and Open offerings. Fund size records its
basis (commitments, raised or target), not the manager's AUM. Location means manager
headquarters for a fund. Vintage never implies a maturity date; stated term,
extensions or evergreen status are maintained separately.

Key People supports names and roles without platform accounts. The table shows
at most two plus a link to the full profile. Optional professional URLs and
explicit, confirmed member associations are maintained by staff. Hidden member
profiles and IDs are not exposed through associations. Financial values remain
missing until disclosed; optional source and as-of date appear on the profile.

SPV is entity metadata on a Companies record, with an identity label and filter.
It is not a sector, category or separate directory. Underlying, Sponsor and Manager
links are optional. Financial values are never copied from related records.
Open offerings counts only accessible, listed, nondeleted, open, nonarchived
Offerings topics linked by the company tag. Nonzero counts link to that active
subset, not to unrelated or completed topics.

Home keeps native category/tag selectors, positioned after navigation as in
Discourse Horizon. The combined directory is labeled All forums and retains /all-forums.
Chat navigation prefers core full-page mode; explicit minimizing remains native.

## Local fund preview

`scripts/discourse-local.sh fund` creates SVDEX Opportunity Fund I for local
layout review, also included in the normal `companies` setup. The account, native
profile, company tag and fund disclosures stay on localhost:4080. Re-running it
preserves edits made through the admin form. No fake people or offering activity
is added, and the script refuses to run on another host.

Develop/review locally and batch releases to svdex.com. This fixture is not part
of the production configuration or upgrade scripts.

The native Users directory includes independently managed personal and organization
accounts, with native group filtering. SVDEX-maintained profiles are excluded. People (`/people`) is a separate staff-curated,
public group directory: it excludes nonstaff company/fund accounts, unnamed
accounts and profiles hidden from the viewer before counts and pagination.
Classification does not assert identity verification, participation or account
ownership. Profiles, posts and mentions remain native. The support category is
named Feedback.

`scripts/discourse-local.sh people` configures the People group and adds guarded
local professional profiles. Production configuration creates an empty group and
never imports these accounts. Add a person through native staff group membership;
keep native profile-visibility settings in mind for inactive/new accounts. Account
handover remains separate from classification.

Company and fund tables retain only the bottom native horizontal scrollbar.
The fund strategy column is labeled Strategy on both desktop and mobile;
its stored strategy/focus field and contents are unchanged.

Responsive fund cards retain native dotted leaders, typography and value text
alignment. Short values sit at the right; multiline values start just after the
leaders, with their wrapped lines aligned to the start of the value. Longer values can use up to 70% of the row instead of reserving over half
for labels. Company cards and desktop table columns keep their existing layout.

Mobile offerings use the directory-style identity and compact financial preview
text everywhere, including the dedicated Offerings category and mixed feeds.
Facts are self-describing, value-first phrases separated by middle dots. Both show the principal instrument term and supporting terms with native
topic/profile/tag links, top-right reply counts, bottom-right
activity and bulk selection. Desktop and ordinary topic cards remain native.
The earlier query-string comparison modes are removed.

Users retains native group choices, including organization groups. Company/fund
search and filter actions use the native default button style; profile fact labels
stay together, and Strategy is used consistently.
Mobile Top date ranges wrap beneath the period name without page overflow.
Search-result metadata follows the feed's category/tag punctuation and single
color cue; the pinned core search button's doubled translated accessible name
is corrected without changing Discourse core files.

## Professional People columns

The People directory uses the native responsive table, user identity and profile
background line, with Current roles, Location and Est. net worth columns. Organization
names and their specific current roles share a cell; Focus remains on
the native profile instead of being a directory column.
Organizations come from existing explicit Key people references on visible company
and fund accounts. Real names supply the Person sort order in both directions.

`configure-people.rb` idempotently provisions seven optional, non-user-editable native
UserFields identified by `external_type=svdex_people`: background, role, focus, net_worth,
net_worth_source, net_worth_date and net_worth_basis. Staff maintain them in the
native user editor. Native profile visibility still controls directory disclosure;
organization relationships do not establish account control. Location and full biography use native user profile fields. The separate Background
field covers experience, education or current studies with named organizations
or institutions where known; it never falls back to the biography when blank.
Keep Key people associations current; put past roles in Background. Production provisioning adds no personal facts.

The directory withholds a net-worth figure unless it also has an HTTPS source,
valid nonfuture ISO date and a written basis. Text estimates can represent ranges
and currencies without fake numerical precision. They are not sorted as numbers.
The native modal shows supporting information when an estimate is clicked. This
completeness check cannot establish source quality; staff must review it. Keep
all public native profile fields accurate and sourced when editing them.

## Management and handover

The hidden staff-only group from `svdex_maintained_accounts_group_name` (default
`svdex-maintained`) marks records maintained by SVDEX. Staff add profiles they
create on behalf of someone else; ordinary registrations need no marker. After a
separately completed handover, remove the record from this group. No login-history,
name, catalog-group, or email heuristic changes classification automatically.
This marker never grants company editing rights or private-offering access.

`/directory_items.json` supplies Users, excluding marked records even under a
native group/name filter, pagination, or signed-in current-user prioritization.
`/people/directory_items.json` and `/listings/company-directory.json` explicitly
select their catalogs through `svdex_catalog` in the server query; their scopes
are fixed by the controller and preserve native group/profile access rules. The
People adapter and pagination use the dedicated endpoint. Native Users keeps its
original route, fields, statistics and group choices. Production provisioning
creates the empty marker group without guessing which existing accounts are
maintained. Local fixture setup marks only its own known records.
