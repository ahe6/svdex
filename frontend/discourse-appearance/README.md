# SVDEX Discourse appearance

SVDEX uses native Discourse Light/Dark palettes, controls, menus, tables, profile
components and responsive behavior. Presentation belongs in the Appearance,
Interface and Sidebar themes; no Discourse core files are patched.

The Sidebar component orders the current main links: Home, Companies, Funds,
Offerings, Discussions, Events, My posts, My interest & bids, My messages,
Achievements, Bookmarks and Users, followed by role-specific staff tools. More
holds secondary destinations such as All tags, Groups and configured Terms/
Privacy links. About/Guidelines are retired. Native standalone Categories, Tags
and Channels sidebar sections are hidden; their underlying data remains native.

Home exposes Tags before New Topic and retains its offerings/official-updates
feed scope. Offerings groups Search company, Sector, Valuation and Latest,
with native Tags before the action group. It has no separate All/Public/Private
selector. Discussions keeps scoped native category/tag choices. Mobile collapses
category/financial controls into the boxed Filters action where applicable; Home
keeps Tags visible. Selected filters use the native primary treatment.

Both Overview routes share a native tag/category directory layout. Desktop has
tags and categories side by side; mobile puts categories before tags. Their
controllers provide different category scopes. The directory template does not
change category permissions.

Desktop offering rows use the instrument-aware Terms column; other topic rows
retain native participant avatars. Mobile uses compact self-describing financial
text and the original-poster identity block. Company/fund directories reuse the
native Users structure and profiles reuse native stats/topics. My interest & bids
uses native Activity navigation, list typography, select-kit controls and modals.

The theme uses a stable desktop scrollbar gutter and avoids duplicate scroll-lock
compensation. Wordmark sizing/alignment is a scoped adjustment; core owns the
hamburger and sidebar placement. Styling changes should remain scoped so ordinary
Discourse screens retain native sizes and behavior.

Install locally with `scripts/discourse-local.sh appearance`; it imports Sidebar
and Interface as well as the parent theme/branding. Theme-only component updates
can use `theme`. Both remain guarded to localhost:4080. Production uses the
paired preserving release procedure.

See [product behavior](../../docs/product.md),
[maintenance](../../docs/discourse-maintenance.md) and
[company/fund data](../../deploy/discourse/company-directory.md) for the current
source and permission boundaries.
