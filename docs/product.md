# Current SVDEX product scope

This is the current behavior of the active Discourse implementation, not a claim
that the local development branch is already deployed. See production records
for live source/settings. Earlier design choices remain in Git history.

## Native foundation

Discourse supplies accounts/profiles, groups, topics/replies, tags/categories,
moderation, bookmarks, messages, Chat, Events, authentication and backups.
SVDEX adds company/fund directory views and disclosures, offering facts,
permission-aware queries and private financial submissions. Presentation is in
native themes; validation and permissions remain in the server plugin.

Company/fund profiles are native user accounts classified by staff-managed groups.
They are distinct from an offering, which is a native topic representing a
particular financing/security. No separate company entity database exists.

## Navigation and feeds

The main sidebar order is Home, Companies, Funds, Offerings, Discussions, Events,
My posts, My interest & bids, My messages, Achievements, Bookmarks and Users.
Member-only links require sign-in; staff tools retain native visibility. More
contains secondary destinations, including All tags, Groups and configured
Privacy/Terms links. About/Guidelines routes are deliberately retired.

Home Latest/Top includes viewer-visible offerings and Company & Fund Updates.
Ordinary discussions, Feedback and community Events are outside that allowlist.
Its visible native Tags selector narrows the existing feed; it does not silently
broaden into the global tag feed. Latest/Top retains the tag selection. Standalone
tag pages remain broader and respect native topic security.

Home and Discussions both have Overview. They share the tag/category directory
UI; Discussions restricts the category side to its community scope. Desktop has
tags and categories side by side; mobile puts categories before tags. The tag
side is a general company/sector/topic navigation directory. These are ordinary
native secured category/tag links, not separate content stores.

Discussions keeps independent Latest/Top, Overview and Chat. Its category selector
contains community choices, without offerings or Events. Chat opens Lounge while
retaining Discussions navigation and the visible native composer. The native
channel directory remains available elsewhere when needed. Events has its own
sidebar destination, native topic view and Calendar alternative. It keeps Tags
without a category selector. RSVP/reminders/preferences remain native.

## Companies and Funds

The organization directory inherits the native Users route/controller and composes
native controls/table components. Ordinary Users omits company/fund accounts
before search, pagination and counts. The organization identity links directly
to its Summary; ordinary user links keep native profile cards.

Current desktop columns after the identity/description area:

| Companies | Funds |
| --- | --- |
| Sector | Strategy |
| Key People | Key People |
| Last valuation | AUM |
| Buy interest | Buy interest |
| Sell interest | Sell interest |
| Total funding | Fund Life |
| Location | Location |
| Open offerings | Open offerings |

Interest columns depend on the configured public-totals/staff-review capability;
visible public totals are available to guests. Financial headers provide native
range/sort choices, including Buy/Sell interest. Filter state persists through
search/sort/pagination. Filters apply before pagination; missing financial values
sort last. Mobile uses native directory cards and separate Search/Filters actions.
Desktop keeps one bottom scrollbar for the directory's real overflow.

Missing disclosures use an em dash, distinct from measured zero. Money uses
compact dollar formatting in directory displays. Sectors capitalize the first
letter and preserve AI without changing stored lowercase tags. AUM is separately
maintained, never inferred from a fundraising target. Strategy is a broad type;
focus belongs in the description. Fund Life displays a disclosed year range or a
start year plus qualified term; it does not invent an end for evergreen terms.

Company/fund Summary shares directory facts and native stats/topics, with linked
updates/offerings and optional supplemental facts. Stage (including Non-venture)
and domicile can remain supplemental; an absent venture stage is not fabricated.
Financial facts are staff-editable validated native custom fields. Native explicit
profile/group privacy remains authoritative. Public classified organization
profiles are visible to guests even when new; ordinary-user privacy is unchanged.

New company/New fund opens native group membership-request intake, with structured
organization/representative/authority details. It does not automatically classify
or verify the applicant. Staff ownership of the group does not make staff a
company. Buy/Sell actions in the directory or Summary open the viewer's own
indication with that side preselected; guests enter native login.

## Offerings and metadata

Offerings is the aggregating parent of native Public offerings and restricted
Private offerings children. The parent is read-only for ordinary members; creating
an offering defaults to the public child and requires native review. Replies keep
ordinary native behavior. Approved figures survive queued-post review and edits.

Desktop has Search company, Sector, Valuation and Latest together, then native
Tags and the New offering action group. There is no separate offerings-category
selector. Mobile uses a boxed Filters action for company search, sector, valuation
and tags; native category navigation retains its own scope elsewhere.

Desktop offering rows use an instrument-aware Terms column in topic lists,
including Home; ordinary topics retain native participant avatars. One primary
term sits above a supporting line. Convertible caps can show discount/rate;
debt shows annual rate above target/minimum. Offering-specific funds raised and a
comparable positive target can show progress. Company total funding never becomes
round progress. Missing/qualified terms remain undisclosed or authored text.
Mobile uses a compact summary and self-describing figures such as
`8%/yr · $2M target · $100 min`, with replies in the native top-right position.

Financial first-post/review details use shared components and validated bounded
native topic fields. A topic's figures never authorize a trade. The first post
has a primary Submit bid action beside Reply when enabled.

Topic metadata uses compact lowercase public/private/updates category labels;
selectors keep full names. A derived visibility tag matching its category is
omitted from that topic's metadata to avoid duplication. Category/tag separation
uses native typography with comma handling and one leading color marker. Native
private locks and unread state remain visible. Optional 506b/506c/4a7 tags are
staff-assigned, not inferred or treated as certification of legal eligibility.

## Private access and achievements

Private-category permission comes from native group membership, not an achievement
or questionnaire submission. Members without access can discover the access
process through a public informational category adapter and dismissible native
notice. It never exposes private topic titles, terms, tags or counts. Authorized
members see native private content under Offerings. The notice covers discovery,
organization profiles and topics while staying out of account settings, Chat and
legal pages.

`/private-offerings` requires login before showing the Tally questionnaire link.
Responses stay with Tally for manual review; the older Google Form is retained.
Staff may archive reviewed records in private native staff cases. Submission does
not automatically grant membership. Private Access badge synchronization uses a
small reliable plugin hook; native Workflows has a tested rate-limit gap and is
not its runtime replacement.

Early Explorer, Verified Accredited Investor and Private Access are native manual
achievements under SVDEX. Accreditation verification is separate from private
membership. Neither a badge nor account membership determines eligibility for
all offerings. Raw verification documents are not collected through a new custom
upload system.

## Interest, bids and owner management

General company/fund interest is canonical per investor/organization/buy-or-sell
side. Updating replaces the saved amount; a legacy offering link remains within
that same canonical record. Interest is positive exact USD cents, nonbinding,
withdrawable and expires after 30 days unless reconfirmed. Restricted-origin
tracking remains sticky when scope changes.

Public totals require explicit aggregate-publication consent and exclude expired,
withdrawn, unconsented and restricted-origin indications. A displayed aggregate
can contain only one contributor; it is not a guarantee of anonymity or funds.
Individual identities/records stay private to their submitter and separately
authorized staff. Directory links open the viewer's own form, not other investors'
terms. Public sorting/filtering uses the same authorized aggregate scope.

Offering bids are separate per investor/offering records: exact USD amount,
required plain-text proposed terms, explicit nonbinding confirmation, 30-day
expiry and withdrawal. They never overwrite or contribute to general interest.
Reads/writes require current native offering access and a unique visible tagged
issuer. Hidden/deleted/non-offering topics reject offering-linked submissions;
closed/archived offerings reject new or updated bids. Company representatives do
not automatically receive others' bids. There is no acceptance, matching, order,
execution or position-tracking system.

My interest & bids links to Activity → Interest & bids. The owner-only view filters
current/expired/withdrawn interest/bids, newest-update first in pages of 25, shows
exact amounts and supports edit/resubmit/withdraw. It displays the latest saved
version, not an immutable history of every edit. Staff cannot request another
owner's history through this endpoint. History/withdrawal remain available when
recording is disabled or source access is lost; inaccessible names, links and bid
terms are redacted. Responses are private and not cacheable.

Separate intake, staff-review and public-aggregate flags default off in production.
Deploying code does not enable them or publish policy edits. Publish the reviewed
Privacy disclosure before activating new financial intake.

## Development and release

Use native themes and components; avoid global restyling of ordinary Discourse
views. Preserve server ownership/permissions, consent and moderation during UI
changes. Local examples belong only in guarded setup/test code and must never be
imported into production automatically. Do not add demo-style labels to the UI.

Source/package tests are lightweight CI. Native workflow/permission/theme tests
and desktop/mobile browser review remain required for relevant changes. Local
work and draft PRs are not automatically live; source parity also does not prove
production settings, data, email delivery or recovery status.
