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
evidence in the native private verification conversation once protected uploads
have been enabled and tested, or in an agreed external private channel.

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
offers Request verification when document intake is ready. This creates a native
private review thread addressed to the configured staff contact, with the saved
amount and company/fund context. Its first post explains the relevant documents,
native reply attachment button and redaction. Buying requests ask for dated
bank/brokerage evidence; selling requests ask for ownership and authority evidence.
It does not verify funds, publish the record or create a public document. Staff
follow up through ordinary native replies. No separate form or file table is added.

The intake follows the native fixed-recipient membership-request pattern, with
ownership/access checks and a five-per-day per-account rate limit. New active
accounts can request review without gaining general private-message privileges.
Suspended accounts cannot use that intake. Native staff correspondence handles
follow-up. My Bids retains edits and withdrawals and labels current uncovered
indications Unverified.

## Protected attachments: activation required

**Current local storage is not ready for financial documents.** It uses local
uploads, Secure Uploads is disabled and PDF is not an allowed extension. No real
documents were received. Subsequent staging storage configuration and probe
results are recorded in [Secure uploads](secure-uploads.md); production is unchanged.

The request endpoint refuses to start document intake, and the member modal hides
Request verification, unless all of these conditions hold:

- `svdex_interest_document_uploads_enabled` is explicitly enabled (default false).
- Native `SiteSetting.Upload.enable_s3_uploads` and `secure_uploads` are enabled.
- `secure_uploads_allow_embed_images_in_emails` is disabled, so statement images
  are not copied into outgoing notification emails.
- `authorized_extensions` includes `pdf`.
- The backend draft-upload ownership guard is installed.

The admin review panel reports when intake is closed. Staff can still record a
manual review from another private channel. Saving/withdrawing interest and public
verification qualification do not depend on document intake being enabled.

Activation is an operations change, not a theme update:

1. Configure native S3 upload storage, using a dedicated uploads bucket rather
   than the private backups/release bucket. Follow the pinned Discourse version's
   [Secure Uploads instructions](https://meta.discourse.org/t/secure-uploads/140017),
   including object ACLs, absence of an overriding public-read bucket policy and
   migration of existing uploads. Do not blindly change existing bucket access.
2. Enable Secure Uploads and disable embedding secure images in email. Add `pdf`
   to the existing allowed extensions without removing image types. Confirm native
   upload limits are suitable and new members can attach a PDF in their review PM.
3. With harmless PDF/image files only, test the complete native composer upload
   and reply flow as a new member. The submitter and recipient must be able to read
   the file; a guest and an unrelated signed-in user must not. Test the Discourse
   secure URL and the unsigned S3 object URL, not just access to the conversation.
   Confirm notifications contain no document bytes. Check public logos still work.
4. Check uploads-inclusive encrypted backups and restore of the protected objects.
   Use an isolated staging bucket and synthetic files; do not copy live financial
   evidence into contributor development environments.
5. Update the published privacy notice to describe this document collection and
   agree on retention. The current notice discourages sensitive-document storage;
   this implementation does not silently revise or publish that notice. Deleting
   an attachment from a post is not proof it has disappeared from backups, storage
   versions, mail or other recipients' copies. No automatic purge is promised.
6. Only after those checks, enable `svdex_interest_document_uploads_enabled`.
   Re-test a new request on the target installation before accepting real files.

Settings are a readiness gate, not proof of correct bucket permissions. Keep the
explicit intake flag off until the real upload/download tests pass. Never disable
Secure Uploads to work around attachment failures on a site holding private files.
These messages remain native staff correspondence even though the social Messages
sidebar opens Chat. General private-message privileges are not broadened.

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
The document-intake checks exercise every missing prerequisite and native request
text/permissions using an isolated requirements stub; they do **not** claim an
end-to-end S3 upload or direct-object authorization test. Subsequent real staging S3 checks are documented in
[Secure uploads](secure-uploads.md). Intake remains disabled until a matching
release, approved disclosure and retention decision are ready.
