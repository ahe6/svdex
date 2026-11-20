# Public directory content

One reviewed JSON file represents one company, fund, person, product or public security.
Pages read database records, not generated HTML. Approved file changes can be
imported without deploying or restarting the application. Hosted automatic sync
is prepared but remains disabled until the independent backend is released; see
[the activation and review process](../docs/public-content-sync.md).

Keep public facts here, separate from `frontend/` application code. Source links
must be public; known financial amounts need an as-of date and source. Unknown
means `null`, not zero. Never put account ownership, credentials, private contacts,
messages, bids, indications of interest or verification documents in these files.

Companies retain the existing `companies/svdex.json` format and local
[correction workflow](../docs/company-catalog.md). Use whole USD integers for
company financial figures. Keep its stable ID, filename and company tag.

Funds, People, Products and Securities use this envelope (folder determines the entity type):

```json
{
  "schema_version": 1,
  "id": "stable-slug",
  "name": "Public display name",
  "summary": "Short description or professional background, at most 180 characters.",
  "tag": "stable-slug",
  "sector": null,
  "location": null,
  "facts": {},
  "sources": [{"url": "https://public-source.example.org/page", "note": "What this source supports"}]
}
```

Use `<id>.json` inside the matching folder. Do not rename a file to rename its
display title. Native public entity tags connect related topics across categories;
no tag is automatically generated for every offering or event.

Allowed facts:

| Folder | Fact fields |
| --- | --- |
| `funds/` | `aum_usd`, `strategy_focus`, `vintage_year`, `fund_life`, `fund_domicile`, `manager_name`, `facts_as_of`, `source_url` |
| `people/` | `role`, `focus`, `birth_year`, `birth_year_source`, `net_worth`, `net_worth_source`, `net_worth_date`, `net_worth_basis` |
| `products/` | `description`, `status`, `company_tag`, `price`, `includes`, `delivery` |
| `securities/` | `description`, `instrument_type`, `topic_id`, `terms`, `valuation_cap`, `conversion_discount`, `strike_price`, `expiration`, `interest_rate`, `offering_size`, `funds_raised`, `total_funding`, `minimum`, `post_money_valuation_usd` |

Facts can be omitted or `null`. Known AUM requires `facts_as_of` (YYYY-MM-DD) and
`source_url`; vintage is a whole year. For age, provide `birth_year` as an integer
or a birth year range such as `"1980–1984"` and `birth_year_source` as a public
HTTPS URL. The directory calculates the approximate age or range. A net-worth claim requires all four
net-worth fields, including a public HTTPS source, date and qualitative basis.
Use a sourced USD amount such as `$1,250,000` or one of four lower-bound bands:
`$100k+`, `$1M+`, `$10M+` or `$100M+`. Pick the highest supported band at
or below the source's lower estimate. SVDEX displays the amount or band, source
and date. Ranges and bands are sorted by their displayed lower bound.
Product `description` and `status` (`launched` or `presales`) are required. Price,
includes and delivery use the existing native product field limits. Products are
native topics; replies remain attached when reviewed content is corrected.
Set `facts.company_tag` to a public Companies tag to link the product to its maker
in the directory. The product keeps its own top-level `tag` for related topics.
A product file with `status: "presales"` creates or updates the permanent product
page. To publish a campaign, use New pre-sale and choose that product in Discourse.

Securities require a public description and an instrument type (`equity`, `safe`,
`convertible_note`, `debt`, `warrant`, or `other`). Use `null` for an unknown
issuer or use an existing public Companies tag. Valuation is a whole USD amount.
Create offerings through SVDEX's native composer. A reviewed securities file
requires `facts.topic_id` for an existing visible Public offerings topic and
retains its replies. Removing a managed term clears its value. The file cannot
create an offering, change visibility, close or reopen it, or import a private topic.

When catalog publishing is available, the site's directory Add buttons open a
draft for the relevant folder. Guests can propose the file through GitHub. Once
the SVDEX GitHub App is connected, a signed-in member
can edit the file on SVDEX and ask the bot to open the public pull request. For an
entry already managed by a file, Suggest changes opens the current file. You can
also create or edit the file directly here. Staff review both paths on GitHub.

Only maintained file fields are imported. Operational account links, logos and
private records stay out of Git. Existing entries need a reviewed initial file
before they can use Suggest changes. Do not add local fixtures to this directory.

Validate locally:

```sh
ruby scripts/build-public-catalog.rb
```
