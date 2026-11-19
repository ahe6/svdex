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

The main sidebar order is Home, Companies, Funds, Offerings, Products, People,
Discussions, Events, Messages, My posts, My Bids, Bookmarks and Achievements. Users
and Groups remain under More.
Member-only links require sign-in; staff tools retain native visibility. More
contains secondary destinations, including All tags, Groups and configured
Privacy/Terms links. About/Guidelines routes are deliberately retired.

Public Home, Offerings, Products/Pre-sales, Discussions and Events views keep
their native create actions visible to guests; clicking one goes to `/login`.
Companies, Funds and People use the same login destination for their add actions.
Add person opens a native private-message draft to the configured staff contact
for signed-in members. Staff review suggestions and maintain People membership;
the button does not automatically publish a profile or grant account ownership.

Home Latest/Top includes viewer-visible offerings, approved Pre-sales and Updates.
Ordinary products, discussions, Feedback and community Events are outside that allowlist.
Its native sector dropdown, labeled Filter, narrows the existing feed; it does not silently
broaden into the global tag feed. Latest/Top retains the tag selection. Standalone
tag pages remain broader and respect native topic security.

Home and Discussions both call their directory Overview. They share the tag/category directory
UI; Discussions restricts the category side to its community scope. Desktop has
categories on the left and tags on the right; mobile puts categories before tags. The tag
side is a general company/sector/topic navigation directory. These are ordinary
native secured category/tag links, not separate content stores.

Discussions keeps independent Latest/Top, Overview and Chat. Category navigation
lives in Overview; the toolbar exposes Filter (sector selection) without a category selector. Chat opens Lounge while
retaining Discussions navigation and the visible native composer. The native
channel directory remains available elsewhere when needed. Events has its own
sidebar destination, native topic view and Calendar alternative. Offerings and Events
do not include the Home Overview link in their mobile navigation. Events keeps Tags
inside Filter without a category selector. RSVP/reminders/preferences remain native.

## Companies and Funds

The organization directory inherits the native Users route/controller and composes
native controls/table components. Users includes independently managed personal, company and fund accounts; profiles
explicitly marked SVDEX-maintained are excluded before search, pagination and counts. The organization identity links directly
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
sort last. Mobile uses native directory cards and separate Search/Filters actions. Directory
controls keep search and Filter together, with a larger gap before Add company/Add fund.
Last Updated is omitted.
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

Add company/Add fund opens native group membership-request intake, with structured
organization/representative/authority details. It does not automatically classify
or verify the applicant. Staff ownership of the group does not make staff a
company. Buy/Sell actions in the directory or Summary open the viewer's own
indication with that side preselected; guests enter native login.

## Products

Products are permanent native topics in their own public category. The catalog
uses native topic rows, author avatars, company/sector tags, a cached description
preview and replies/views/activity. New submissions require review; replies and
edits use the native workflow. The post body holds product descriptions, company
profile links, websites and links to related pre-sale campaigns. There is no new
product-account system, checkout, bidding or financial field storage. Ordinary
products do not enter Home's financing/updates feed. Local fixtures are installed
by `setup-products-local.rb`; deployment config creates only the empty category.

## Pre-sales

Products combines regular products and pre-sales in one Latest/Top list. Pre-sales
is a native subcategory of Products; the Filter panel selects All products,
Products only (no subcategories), or Pre-sales only. Offerings keeps only its
Latest/Top securities navigation; pre-sales is reached through Products. Both
product views activate Products in the sidebar. Creation forms and campaign terms
remain separate; mobile uses the native navigation dropdown.

Pre-sales is a public native subcategory for product preorders and early
access. Its filtered view uses Latest/Top with the shared structured topic layout:
product title/summary, Terms, and native replies/views/activity. Terms emphasizes
the purchase price and unit or access period, followed by what buyers receive
and expected delivery. Mobile uses the same compact card presentation as Offerings.

Five bounded native topic custom fields store summary, price, included product,
expected delivery and other terms. The native composer, drafts, first-post edits
and review queue carry those fields. New member topics require review; replies
use normal native behavior. Approved products also appear in Home.

Presentation is shared with Offerings; product data and securities data remain
separate. Pre-sales do not accept securities bids, gain public/private offering
tags, or contribute to company/fund offering counts. There is no checkout or
payment processing. Local fixture products are installed only by the guarded
`setup-presales-local.rb`; release configuration creates only the empty category.

## Offerings and metadata

Offerings is the aggregating parent of native Public offerings and restricted
Private offerings children. The parent is read-only for ordinary members; creating
an offering defaults to the public child and requires native review. Replies keep
ordinary native behavior. Approved figures survive queued-post review and edits.

Desktop Offerings keeps native Latest/Top tabs at the left, with the result count,
Search offering, its permission-aware matching count, Filter and Add offering actions at the right. There is no
separate offerings-category selector.

Home and Discussions expose a native sector dropdown labeled Filter
after search; Offerings uses its broader filter panel.
It contains only the Sectors tag group, preserves non-sector tag/search criteria,
and retains each page's feed/category scope. Clearing a sector from a native
category-tag URL returns to the same category without retaining that sector.
There is no additional Filter button on Home or Discussions. Companies and Funds
retain their broader screening Filter panel; Events retains its Filter panel.
Creation uses native blue primary buttons. Add company/Add fund and native
New topic/offering actions use the same 0.5em horizontal gap as Discourse
category/tag dropdowns (8px at the current text size). Mobile directory headings, Search, Filter and Add controls share one row;
catalog counts sit beneath it, including zero-result counts.

Home/Discussions/Events omit result counts; Companies/Funds retain their catalog
counts. Desktop Offerings shows its full filtered count beside Search offering,
before pagination and excluding inaccessible/unlisted topics. Offering search
matches company names and security titles; company-name suggestions remain native
autocomplete choices.
Topic search submits with Enter through native search and preserves current scope.

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
For real offerings, include the applicable `506b`, `506c` or `4a7` tag once staff
have confirmed the offering's stated exemption. Keep this classification explicit
in the publication review.

## Private access and achievements

Private-category permission comes from native group membership, not an achievement
or questionnaire submission. Members without access can discover the access
process through a public informational category adapter and dismissible native
notice. It never exposes private topic titles, terms, tags or counts. Authorized
members see native private content under Offerings. The dismissible private-access
notice appears only on Home feeds/Overview and accessible offering category/tag
views. Discussions, Events, topics, profiles, account screens and legal pages do
not show it. Companies/Funds retain their separate interest-column tip.

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

My Bids links to Activity → Interest & bids. The owner-only view combines
current/expired/withdrawn interest/bids without type/status controls, newest-update
first in pages of 25, shows
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

Personal interest/bid history is currently unfiltered, with no type or status
controls. Edit uses a flat native action; interest withdrawal is in a row menu,
while bid withdrawal remains in its editor. Mobile cards use explicit left-aligned
“Buy/Sell interest: amount” or “Bid: amount” and “Status: state” rows, with Updated
and actions below; there is no repeated heading or duplicate submission label.
Administrative category/tag editing sits at the far right, after notification controls.

Home and Discussions Overview directories omit Sector, Filter and New topic
controls. Posting remains available from their topic feeds.

Composer category choices exclude the aggregating Offerings parent; authorized
child categories retain native hierarchy and permissions. Add/New toolbar actions
share the native plus icon.

## Offering instruments and composer scope

Offering details includes a native Instrument selector: Equity, SAFE, Convertible
note, Debt / bond, Warrant and Other. Common summary/funding/target/minimum/terms
fields remain available. Equity adds valuation; SAFE adds cap/discount; convertible
notes add cap/discount/rate; debt adds rate; warrants add strike/expiry. Other shows
all fields. Switching types keeps entered values, including across a saved draft;
the shared figures renderer displays only terms applicable to the saved type.

The type is the validated native topic custom field `svdex_instrument_type`.
It uses the existing metadata create/edit/draft/review/serialization pipeline and
requires no separate table. Existing untyped offerings retain their current display;
the composer infers a suitable starting selection from their title/terms.

The Add offering category chooser includes only the viewer-authorized Public and
Private offerings children. A new composer opened from Home or Discussions excludes all three
offering category IDs and retains the other native authorized categories. Scope
stays with that composer when its selected category changes. The composer header
uses native child-category badges without the redundant parent prefix.

### Directory organization counts

The Users directory retains Discourse's activity columns and adds **Organizations**.
This is the number of visible company/fund profiles that explicitly link the member
through a Key people account reference. It is not an ownership claim. Duplicate
references count once per organization; hidden profiles and private memberships
are excluded. The count is current, independent of the directory's activity period,
and supports ascending/descending sorting before pagination.

### Browsing and submission controls

Discussions orders its tabs Latest, Top, Chat, Overview. The embedded Lounge keeps
these tabs but omits discovery search, filters, creation and category administration.
Overview keeps the same tab placement as feeds. Offerings uses a full filter panel
(company search, sector, valuation and native tags); Home/Discussions retain their
simple sector dropdown labeled Filter. Toolbar creation keeps native draft resume,
without the split draft menu; drafts remain accessible in profile Activity.

My Bids uses one Edit action per editable submission. Bids retain withdrawal in
their editor; company/fund indications put withdrawal in the row's action menu,
with a confirmation naming the organization and buy/sell side. A standalone
Withdraw action remains when editing permission is lost but withdrawal is allowed.

Buy/sell interest pop-ups are focused, fixed-direction forms. They show amount,
buy-market preference, existing indication context and the nonbinding consent,
without a staff ledger or a withdrawal action. Saving updates the same indication,
refreshes totals and closes the form. Companies/Funds use the native global notice
to explain their clickable interest columns, replacing the private-access prompt
only on those directories.

### Application and event entry points

Add company/Add fund opens the same application form for staff, applicants and
approved representatives. New applicants use native membership requests. Already
approved members/staff send another application to the group's owners as a native
private message, rather than requesting duplicate membership. Nothing publishes
an organization profile or grants privileges automatically.

New event opens the bundled Events plugin's date/time builder before the composer.
The chosen event name, timezone, start/end and other native settings carry into the
draft. Calendar selections already supply event markup and bypass this extra
step. Canceling the builder does not create a topic. Event topics keep native
publication, RSVP, privacy and reminder behavior.

The private-access notice explains approval and links to the investor questionnaire;
Companies/Funds retain their separate interest-column tip. Mobile offering avatars,
titles, financial previews and metadata share the native topic row's 55px identity
inset on both Home and Offerings. Mobile Add company/Add fund uses the same native
icon-only plus button as topic creation, retaining explicit accessible names;
desktop retains the text labels. SVDEX achievements retain native bronze/silver
icon colors without custom blue/green verification-status overrides.

### Mobile profile and topic consistency

Company/fund profiles start with the native collapsed profile header on mobile,
with native Expand/Collapse controls. Ordinary profiles and hidden-profile access
rules retain core behavior; desktop organization profiles remain unchanged.
Offering titles in mobile feeds use the same native title size and regular weight
as ordinary topics. Summaries, financial preview text and metadata retain their
existing sizes and identity inset.

Private-access and directory interest notices use shorter mobile copy while
retaining the full desktop explanation and native dismissal. The Lounge chat
panel aligns to the Discussions toolbar content edge on desktop.

Native nested replies are enabled and the default topic view locally. Fresh-site
and upgrade configuration carry the same native settings for the next release.
Private messages retain core behavior; this does not change permissions or the
mobile composer. No custom reply renderer is introduced.

### People and Users

`/people` reuses the native Users directory table, search, sorting and profiles.
The public, staff-curated `people` group selects named individuals; company/fund
accounts and profiles hidden from the viewer are excluded before counts and
pagination. Names alone never enroll an account. The initial period is All time,
so inactive staff-maintained profiles can appear. Group membership does not verify
identity, transfer account control or imply participation. Account handover remains
a separate staff process using native account controls.

`/u` is labeled Users and includes independently managed accounts of every type.
Its native activity columns and optional group filters remain available. Production setup
creates an empty People group; local professional fixtures are never published.

People columns are Person (real name, photo and a short background line), Current roles,
Location and Est. net worth. Current roles pair each organization with its specific
role underneath. Details are vertically centered on desktop and remain left-aligned.
Focus and general role remain available as native profile fields. They use native responsive directory
rows instead of account activity stats. Organizations reverse explicit Key people
account links, respecting profile/group visibility. Person sorting uses real names.
Background, Role/Focus and net-worth disclosures are optional native UserFields
maintained by staff; location and full biography remain native profile fields.
The directory background covers relevant experience, education or current studies and is independent of the
biography. Missing background stays blank. Staff keep organization Key people
links current; past roles belong in Background. Directory estimates
require an HTTPS source, valid as-of date and written basis; missing estimates use
an em dash. Clicking a disclosed estimate opens its source, date and assumptions.
Users retains its existing activity columns.

### Account management

The private, staff-only `svdex-maintained` group is an explicit management marker,
separate from People/Companies/Funds catalog membership and from login activity.
Ordinary registrations are participants by default. When creating a profile on
someone else's behalf, staff add it to this group. After completing an account
handover, staff remove it. This classification grants no permissions and does not
perform the credential/email handover itself. Independently operated company and
fund accounts appear alongside personal users in `/u`.

The native Users directory excludes maintained accounts before counts, searching,
group filtering, pagination and current-user prioritization. Explicit company/fund
and People catalog endpoints retain these profiles while preserving native group
and profile permissions. Catalog membership alone never implies account management.
Production configuration creates an empty management group, without reclassifying
existing accounts. Local setup marks only its known fixture accounts.

People's Filter action opens native controls for current organization and location.
Selections apply immediately, persist in the URL and pagination, and can be cleared.
Choices derive from all accessible curated profiles, not just the current result
page. Hidden organizations/people do not contribute filter choices or counts.
The offerings count precedes the offering search input, matching catalog searches.

Key people in company/fund directory cells show linked names on one line, with
roles available on hover and in full on profiles. Names contribute their full
intrinsic width to the scrollable table. Directory searches use a compact 12rem desktop width; topic and offering
searches use 14rem for longer queries. Controls keep their native height and
fluid mobile layouts.

## Discovery attribution

Companies, Funds and People retain separate discovery provenance on native user
profiles. Classification captures the first SVDEX indexing timestamp; it never
assumes that the account owner, current editor or staff importer discovered the
entity. Existing records are backfilled as staff-added with an unknown listing
date. Imported/staff-added records show that source without personal discovery
credit. Self-listed records are labeled explicitly and do not count as discoveries
of other entities. An indexed Person is not proof of registration or endorsement.

Staff review discovery credit under the native Admin user details page. Accepting
credit requires a named, substantive profile, an explicit contributor, a known
listing timestamp and a review reason/evidence. Staff must resolve duplicates and
source quality. These checks support manual review; they are not an automated
notability or duplicate detector. Ordinary profile editing and ownership changes
cannot assign credit. Existing timestamps cannot be rewritten; original entity
and first contributor IDs survive later audited corrections.

Profiles show a compact attribution and contributor Summary shows up to five
visible discoveries, linked to Activity → Discoveries. The full history shows all discoveries newest first with pagination, without filter dropdowns.
Names include the same staff-maintained background used in People, or the existing
company/fund description. Type/date filtering remains available in the underlying
API for future use. Native user
profile and directory-group permissions apply before counts, previews and pages;
removed entities and withdrawn/disputed credits contribute no public counts.
Staff evidence/audit history is not public. No new sidebar item or automatic
achievement scoring is introduced.

The plugin stores provenance plus append-only review/merge snapshots in
`svdex_discoveries` and `svdex_discovery_events`, included in normal Discourse
PostgreSQL backups. Native account merges move current references while retaining
original IDs. Duplicate entity merges preserve both records and hide credit until
staff reconcile the conflict. Deletion nullifies live account links without
removing historical audit records. These records have the same staff-only audit
retention requirements as other moderation evidence.

Use `npm run check:discourse` for permissions, capture/review, corrections, native
merges, deletion, sorting and pagination regression coverage. `bash
scripts/discourse-local.sh discoveries` initializes provenance and local visual
fixtures. Production release configuration initializes only actual directory
classifications; local credit fixtures never enter production.

People Summary includes Affiliations, styled like the Discoveries preview. It
reuses explicit current organization Key People links, roles and native account
avatars; it does not infer affiliations from names or biography text. Duplicate
links are collapsed, and native profile/group visibility excludes hidden
organizations (including funds whose directory membership is restricted).
Company/fund Summary keeps the native section headings, smaller fact typography,
equal native text-button Buy/Sell interest actions immediately beside the details heading, and discovery
attribution below its main content. Submission and consent behavior is unchanged.
