# SVDEX native information pages

The local regression is included in `npm run check:discourse` and verifies guest visibility, staff-only editing, repeat application and unchanged topic activity.

The policy text describes the current Discourse service and the current Tally private-access questionnaire and retained older Google Form. It does not reuse the retired wallet/transaction documents.

**Operator confirmed by the owner: Miscdex Inc.** Use that name and austin@svdex.com as contact. The owner also confirmed Delaware, United States as the incorporation jurisdiction. Describe incorporation accurately rather than claiming it is the operational headquarters. Local previews without an operator configuration use the SVDEX brand without asserting an entity or location. The proposed 18+ minimum, content license, moderation rules, retention description and no-sale/no-advertising statements need owner review with the rest of the text. Applicable legal requirements depend on the operator and users; this is not a determination of compliance.

`apply-site-pages.rb` creates/revises native staff-editable topics and connects them to `/privacy` and `/tos`. It leaves the existing Guidelines topic untouched. Existing topic IDs and activity dates are preserved. Repeated application does not create additional policies. It neither imports user data nor awards access/badges. Core serves static policy bodies publicly; the source topics remain staff-only.

Local preview:

```sh
docker cp deploy/discourse/site-pages/. miscdex-forum:/tmp/svdex-site-pages/
docker cp deploy/discourse/apply-site-pages.rb miscdex-forum:/tmp/apply-site-pages.rb
docker exec -u discourse miscdex-forum bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/apply-site-pages.rb'
bash scripts/discourse-local.sh appearance
```

Production requires `SVDEX_APPLY_SITE_PAGES=1` and `SVDEX_SITE_PAGES_CONFIG` pointing to a private JSON file with the confirmed `operator_name`, an optional confirmed `operator_jurisdiction`, ISO `effective_date`, `approved: true`, and `approved_content_sha256` matching the reviewed two-file source hash printed by local setup. Do not set approval before the owner approves the operator and the concrete text. Preserve a private native topic/settings snapshot before applying; use the existing native theme deployment procedure for navigation changes. Policy publication itself needs no application rebuild or new database. Removing the old page routes is a plugin change and follows the normal release path.

Remove About and Guidelines from the sidebar and native information-page tabs. The plugin returns native 404 responses for About and Guidelines/FAQ/rules/conduct pages, including SPA data requests. The old Guidelines source topic is retained privately and unlisted; no user posts or award history are deleted. Terms contains the basic usage rules without depending on a separate Guidelines document. More exposes Terms/Privacy only when those native pages exist. The Welcome link is updated to Terms once the policies are installed.

Before publishing, verify the operator decision, current provider/retention/analytics settings, Tally and retained Google Form questions and public badge visibility. After publishing, check guest static routes, native signup links, mobile layout and Google OAuth branding links. Keep SVDEX policy links in the external questionnaire and Google sign-in branding; a provider's own privacy policy does not describe SVDEX's use of submitted answers. Announce material terms changes appropriately; existing accounts are not automatically treated as having provided a recorded new consent merely because the text changed.

Research used when drafting: [FTC privacy/security guidance](https://www.ftc.gov/business-guidance/privacy-security), [California DOJ privacy-notice guidance](https://oag.ca.gov/news/press-releases/attorney-general-kamala-d-harris-launches-new-tool-help-consumers-report), and the installed Discourse `StaticController`/native page settings. Do not assume California-only guidance determines which laws apply.

Run `retire-information-pages.rb` after installing the updated plugin to unlist the old staff topic, disable the obsolete Read Guidelines badge, and remove dead links from the system Welcome post. It is separate from policy publication, so it does not assert the still-undecided legal operator.

The native `faq_url` pointer targets Terms after publication so system help/email links have a working destination. The retired standalone FAQ/Guidelines routes remain unavailable.
