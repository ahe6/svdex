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

The ordinary Users directory excludes company and fund group members before
counting, sorting and pagination, including name searches and current-user
prioritization. The Companies/Funds directory scope still includes them, and
profiles, posts and mentions remain native. The support category is named Feedback.

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

Frontend review also keeps organization groups out of the ordinary Users group
selector, gives company/fund search and filter actions the native default button
style, keeps profile fact labels together, and uses Strategy consistently.
Mobile Top date ranges wrap beneath the period name without page overflow.
Search-result metadata follows the feed's category/tag punctuation and single
color cue; the pinned core search button's doubled translated accessible name
is corrected without changing Discourse core files.
