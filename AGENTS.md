# User-facing design preference

Never add demo, example, fictional, sample, local-preview or similar meta labels,
banners, badges, captions, footers or disclaimers to the product UI. The user has
repeatedly rejected them. Use realistic content without this framing. Keep fixture
identification in source code, tests and developer documentation, not the design.

Preserve actual offering access controls, legal consent documents and transaction
behavior. This visual preference does not authorize deploying the local work.

# Development workflow

Develop and review SVDEX changes locally by default. Batch production releases
periodically rather than deploying every UI tweak. Local fixture accounts and
invented financial figures must never be imported into production automatically.

For CSS, templates and theme JavaScript, use `npm run dev` for local save-to-preview
updates. Do not rebuild the app, resync the plugin or run the full native/browser
suite between ordinary visual tweaks. Review the affected screens while iterating,
then run relevant checks after a batch. Stop the watcher with `npm run dev:stop`
before native checks or other theme import commands. Full PR/release checks remain.
