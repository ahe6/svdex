# Public directory content

One reviewed JSON file represents one durable company, fund, person or product.
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

Funds, People and Products use this envelope (folder determines the entity type):

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
| `people/` | `role`, `focus`, `net_worth`, `net_worth_source`, `net_worth_date`, `net_worth_basis` |
| `products/` | `description`, `status`, `price`, `includes`, `delivery` |

Facts can be omitted or `null`. Known AUM requires `facts_as_of` (YYYY-MM-DD) and
`source_url`; vintage is a whole year. A net-worth claim requires all four net-worth
fields, including a public HTTPS source, date and description of its basis.
Product `description` and `status` (`launched` or `presales`) are required. Price,
includes and delivery use the existing native product field limits. Products are
native topics; replies remain attached when reviewed content is corrected.

Staff can curate the public files following non-GitHub submissions, so contributors
do not need a GitHub account. Only maintained file fields are imported; operational
account links, logos and private records stay out of Git. Empty directories contain
no fixture content and are not a request to publish invented financial data.

Validate locally:

```sh
ruby scripts/build-public-catalog.rb
```
