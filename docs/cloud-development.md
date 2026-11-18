# Working without a local SVDEX installation

Codex cloud or another remote editor can edit this repository and open pull
requests without AWS credentials or access to production data. A full Discourse
installation inside the editing environment is optional: GitHub's isolated native
job builds it and checks the PR. A Codex cloud environment itself has not yet been
provisioned or verified by this repository.

## Editing environment

Use Node 24+, Ruby, Python 3, Bash and Git. Install dependencies with `npm ci`.
Run `npm run check` for source, packaging and unit checks. After changing styles,
run `npm run build:styles` and include the generated stylesheet. No live account,
OAuth secret, database export or cloud credential is needed.

For interactive local/remote Discourse development, use the Docker procedure in
[operations](operations.md). That procedure requires a usable Docker engine and
private forwarded ports; do not assume every cloud editing environment provides
one. Do not make the local administrator or Mailpit public to obtain a preview.

## Pull request verification

Open a focused PR from an updated branch. GitHub runs the required source and
native checks. Relevant code changes also run Chromium guest-navigation checks at
1280px, 900px, 375px and 320px against the disposable loopback forum. These cover
creation/login entry points, private-access links, offering tabs, product filters,
page errors and horizontal overflow. The `browser-review-*` artifact contains an
HTML report and screenshots for human review. It contains no account credentials,
authentication state or production data. Pixel-perfect screenshot comparison is
not enforced: screenshots still need an aesthetic review.

The browser suite is intentionally guest-only and read-only. Native Ruby checks
cover signed-in permissions, ownership, private records and submissions. For
local browser checks, run `npx playwright install chromium --only-shell`, then
`npm run check:browser`. An installed Chrome can be used locally with
`SVDEX_BROWSER_CHANNEL=chrome npm run check:browser`. Do not run these concurrently
with native checks or theme imports. The target is fixed to localhost:4080.

## Preview an explicitly reviewed PR

After inspecting the PR and its passing required checks, a maintainer can open
**Actions → Preview SVDEX staging → Run workflow**, select **staging** as the
workflow branch, and enter the PR number in **reviewed_pr**. Equivalently:

```sh
gh workflow run deploy-staging.yml --ref staging -f reviewed_pr=123
```

The workflow resolves the exact open, non-draft PR head, requires current main to
be included and requires successful source/native checks. It rechecks the head
before obtaining deployment access. It checks out that revision, deploys it with
the existing staging identity, and records that actual revision in the receipt.
It does not write repository branches or give cloud editors AWS credentials.
The staging branch must contain this workflow version; bootstrap it through the
normal reviewed staging push when first introducing the workflow.

Staging is shared and serialized, so preview one candidate at a time. It remains
login-protected with email disabled. Use the disposable CI screenshots to review
guest screens; staging's login wall is not a guest-access test. Never supply a
production administrator password to a contributor or automated browser task.

Review staging, then merge the same source to main. Production retains its fresh
native checks, exact-tree staging gate, backup and verification. A new PR commit
requires a new preview. A cloud-only development task can therefore reach a
reviewed release without anyone's laptop running Discourse.

## Deliberate remaining limits

There is no per-PR server, automatically approved community deployment, or
fully unattended aesthetic review. A privileged staging preview is a maintainer
trust decision; do not run arbitrary public PR code before inspecting it. A
server/theme-only fast deployment path and reuse of CI evidence are deferred:
removing the full build safely needs separate artifact and compatibility work.
