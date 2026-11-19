# Private capacity reviews for interest

Implemented locally; not deployed. This is a credibility filter for nonbinding
interest, not an accreditation decision, commitment, reservation or execution system.
No existing account is automatically verified and no reviews are imported from GitHub.

## Data and ownership

`svdex_interest_verifications` holds private staff records with subject account,
USD amount in exact cents, check date, expiry date, reviewer and evidence reference.
Buying capacity is account-wide. Sell reviews require a typed company/fund target
and a description of the holding and authority checked. Account-backed organizations
and independent company profiles have distinct target types even when IDs coincide.
Do not store bank credentials or statement contents in the reference field; retain
evidence in the agreed private verification channel.

Admin → Users → the investor's details contains Interest verification. Staff record
an amount, dates and a private evidence reference. Seller reviews also require the
holding and its company/fund. The form defaults expiry to 90 days; staff must choose
an expiry no more than a year after the check date. Expiry dates use the server's UTC
date, inclusive. Public data files and profile/user serializers expose no review
amount, evidence reference or staff history. Owners see their own dated limit in
the signed-in interest form; evidence references and the administrative history are
staff-only.

A replacement appends a new review and supersedes its predecessor. Revocation is
recorded, not deletion, and never reactivates an older higher limit. A new review
with bad input cannot invalidate the existing one. The native staff log records
review/revocation IDs without copying private evidence or capacity amounts into it.
Native backups include the table. Subject-account deletion cascades its records,
consistent with existing interest retention; reviewer deletion clears the live link
while retaining the original reviewer ID. Verification is not transferred by public
file changes, profile linking or changing organization type.

## Public totals

Public aggregation requires all existing disclosure rules **and** a current review
covering the whole indication: consent, permitted public origin, current verification
and sufficient amount. The existing expiry/withdrawal logic still governs active
interest. Over-limit indications stay privately saved and are excluded in full;
they are not truncated to the reviewed amount. Revocation, expiry and lower limits
immediately affect directory amounts, sorting/ranges, profiles and offering-scoped
interest sums through the same aggregation scope.

A person may express alternative buy interests in several companies up to the same
reviewed capacity. These amounts are not reservations and must not be presented as
distinct available capital summed across the site. Sell capacity applies only to
the reviewed company/fund and holding. Bids remain their existing separate private
workflow; this change does not approve bids or transactions.

Authorized internal staff preview, when public totals are disabled, can still show
unreviewed submissions for investigation. Its totals are not public verified totals.

## Member flow

Interest remains a signed-in site form. It can save an unverified amount privately.
The form shows the owner's capacity status and, after saving an uncovered amount,
offers Request verification. This creates a native private review thread addressed
to the configured staff contact, with the saved amount and company/fund context.
It does not verify funds, publish the record or create a public document.

The intake follows the native fixed-recipient membership-request pattern, with
ownership/access checks and a five-per-day per-account rate limit. New active
accounts can request review without gaining general private-message privileges.
Suspended accounts cannot use that intake. Native staff correspondence handles
follow-up. My Bids retains edits and withdrawals and labels current uncovered
indications Unverified.

## Validation

The native verification check covers private staff-only history, exact limits,
unverified saves, one-cent over-limit exclusion, consent, owner isolation,
new-account intake, company/fund scope, typed-ID collisions, replacement, expiry,
revocation and public response redaction. Public-interest fixtures receive explicit
transaction-only reviews; local setup creates no fabricated persistent reviews.

Local validation on 2026-11-19: all 56 source tests passed, together with the
interest-verification, public-interest, independent-company, marketplace-flows,
my-interest and offering-bids native check groups. The staff review form, holding
selector and member modal were reviewed at desktop and 375px mobile widths.
