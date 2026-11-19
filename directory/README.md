# Public directory facts

This is the first local company-data slice. It does not publish to svdex.com or
replace the Funds/People directories. The existing Discourse pages read a database
projection of reviewed files; they are not generated static HTML pages.

Edit `companies/svdex.json` to propose changes through GitHub. Keep the stable `id`
and filename unchanged. Use whole USD integers or `null` for unknown financial
figures. Known figures require an `as_of` date and a public source URL. Describe
public sources; never include login credentials, account-owner contact details,
private correspondence, bids or interest records in these files.

Run the same offline format checks as CI:

```sh
ruby scripts/validate-company-catalog.rb
node --test test/company-catalog.test.js
```

People can also use **Suggest changes** on the company profile. That sends a private
Discourse review thread to staff. The contributor does not need GitHub. Staff can
prepare a data-file proposal from that submission, review it and make the ordinary
repository change. Submission itself never updates public facts.

See [the local workflow](../docs/company-catalog.md) for preview, import and review.
