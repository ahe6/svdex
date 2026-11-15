# Frontend visual review — 2026-11-15

Local review of the current source, including the pending mobile polish. This is
not a production deployment or a claim that every possible Discourse screen was
examined.

## Coverage

Reviewed the main desktop and mobile experiences at 1280px and 375px, with
additional 800px and 320px checks for crowded controls. Used guest, ordinary
member and administrator views; checked dark mode and selected light-mode views.

- Home feeds and Overview; Offerings, Discussions and their navigation/filter menus.
- Company/fund directories, profiles, filters, search and no-results state.
- Company application, offering composer, interest form and bid/activity states.
- Events/calendar and event detail, including the native RSVP layout.
- Chat shell, global search, Users, Achievements/details, groups and grouped tags.
- Sidebar/More, bookmarks/messages empty states and account preferences.
- Private-access information, Privacy and Terms.

Native preferences and ordinary member states were inspected without changing
existing account credentials, sending messages, submitting applications or placing
bids. Local financial activity fixtures exercise populated activity states; they
are guarded against use on production.

## Changes made

- Kept directory create/search/filter controls together on mobile; compact create
  buttons retain accessible names on the smallest viewports.
- Adapted directory controls to narrow desktop content widths with the sidebar open.
- Reduced offering term-column pressure at intermediate desktop widths, preventing
  severely wrapped titles and an unnecessarily tall toolbar.
- Added a clear-search action to directory no-results states.
- Removed unsuitable Overview choices from Offerings/Events mobile navigation and
  kept the discussion directory label distinct from Home.
- Aligned application inputs, stopped pre-filling a company name with a person's
  name, and retained the representative's name in the appropriate field.
- Corrected premature required-field error styling before an application attempt.
- Made the access notice concise, kept its link together and improved its contrast.
- Put optional offering composer fields in a disclosure so the editor remains usable.
- Used native interest dropdowns and consistent field widths; moved the existing
  explanation into a disclosure while preserving visible consent wording.
- Shortened topic-list public/private visibility labels without altering tag URLs
  or filter behavior; corrected the Offerings sidebar active state.

## Limits and follow-up

Registration is disabled in this local environment, so a complete new-account
signup was not exercised. External questionnaire submission, actual email delivery,
real financial submissions and every administrator screen were outside this
visual review. Native light-theme header icon colors were left intact after
confirming they come from Discourse rather than SVDEX overrides.

Changes remain local for a later batch release. A production spot check is still
needed after deployment because live content and permissions can differ.

## Validation

The final source check and all 18 source tests passed. The complete local native
Discourse verification suite passed, including theme compilation, directory and
filter behavior, permissions, interests, bids, events and policy configuration.
`git diff --check` passed.


## Follow-up full review

Reviewed desktop at 1440px and mobile at 390px and 320px. Covered Home feeds and
Overview, Offerings and offering topics, Discussions feeds/Overview/Chat, Events
list/calendar, Companies/Funds and their summaries, screening/search/empty states,
Users, Achievements, All tags, My Bids populated and empty states, bookmarks,
messages, private-access information, login/signup, Privacy and Terms. Used a
regular member in light mode, staff in dark mode, and selected guest views.

### Follow-up fixes

- Restricted the private-access notice to Home and offering category/tag views,
  retaining native dismissal. Other discovery pages, profiles and topics omit it.
- Verified that Discussions Top and Chat share exactly the same navigation
  position on desktop and mobile after removing the notice. Restored the active
  Discussions sidebar link on Lounge chat and category-tag views.
- Put mobile directory titles, Search, Filter and Add on one row at both narrow
  widths. Counts sit below and remain visible at zero results.
- Used a native boxed recovery button for directory empty states and a native
  associated Sort by label matching the filter fields.
- Disabled bid submission until amount, proposed terms and nonbinding confirmation
  are complete, matching the existing interest-form readiness behavior. Verified
  the disabled/enabled transition without saving a bid.
- Corrected AI display spelling in the native tag renderer without changing its
  canonical slug or URL. Removed duplicated review-step copy on private access.

### Remaining design choices

The expanded native organization profile header is tall on mobile: the logo,
identity, profile actions, membership facts and tabs push company/fund financial
facts below the first screen. Those facts fit at 320px without document overflow.
Using Discourse's collapsed profile header on mobile would improve access to the
facts, but is a separate profile-design choice rather than an alignment repair.

The native Calendar toolbar is busy at 320px and wraps, but remains usable without
horizontal page overflow. Its native controls were retained.

Local registrations are still disabled. Existing-account login and the rendered
signup form were inspected; no new account was created. This is a local setting,
not a statement about production registration. No applications, messages, bids,
interest changes or event attendance were submitted during this browser review.

Follow-up source validation: 30 tests pass and `git diff --check` passes. The full
native suite completed with one stale portability allowlist failure: it accepted
official Chat imports but omitted the bundled Events builder used by event
creation. The allowlist now permits only those two official bundles; its targeted
rerun passes theme export/import, compilation and dependency checks. Every other
native check passed in the full run. Changes remain local pending a later
deployment.


## Mobile profile/title follow-up

- Tried native collapsed company/fund headers on mobile and verified Expand and
  Collapse. Financial facts now appear on the first screen at 390px and 320px.
- Matched offering titles to ordinary topic titles (18.3792px at the current
  settings, regular weight). Summary, terms and metadata sizes are unchanged.
- Shortened mobile private-access and buy/sell-interest notices.
- Moved Messages above My posts, Achievements below Bookmarks, and Users into More.
- Aligned Lounge's desktop panel to the exact toolbar edges (343.71875px through
  1400.28125px at a 1440px viewport). Mobile retains the native chat header.
- Enabled native nested replies and its default view locally. The nested offering
  first post retains financial details and Submit bid. Mobile composer retained.
  Production scripts record the native settings for a later authorized release.

This resolves the earlier tall mobile organization-header follow-up.

Validation for this follow-up: source checks and 30 tests pass; native theme
export/import/compilation, reviewed upstream contracts and idempotent production
configuration checks pass. `git diff --check` passes. No deployment performed.

## Pre-commit navigation/search follow-up

Users and Groups are adjacent in More, using native link classes through the
theme API. Home New topic omits offering categories; dedicated New offering retains
both permitted children. Desktop Offerings uses Search offering and an exact
matching count. Native query filtering and Guardian scoping precede the count query, which runs
before pagination and native pinned-topic splitting. Guests never count private
or unlisted topics. Security-title queries work in addition to company-name searches. Local
transactional tests cover filtering, pagination, zero matches and private access.
Browser review confirmed the 5 offerings to 1 offering transition for SAFE.
