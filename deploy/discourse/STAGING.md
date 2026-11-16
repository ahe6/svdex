# Staging and automatic releases

Development stays local until a maintainer pushes a clean candidate to the trusted
`staging` branch. **Preview SVDEX staging** runs source checks, builds the pinned
forum, imports the native themes and verifies isolation. Review desktop/mobile at
https://staging.svdex.com before merging the same candidate into main. The staging
branch is persistent; feature branches and forks never receive staging credentials.
Do not run unreviewed public PR code in a privileged `pull_request_target` job.

Main requires successful source/native checks on pull requests. Documentation-only
PRs still report the required native job, but skip building a forum; production
always runs the complete native checks. **Deliver SVDEX production** then
runs fresh native checks, verifies the successful staging source tree, backs up the
live site, and deploys without a separate approval click. Merging is the release
decision. If main advances while a release is queued it is refused. If the source
differs from staging, push the new candidate to staging and review it first.
Documentation-only changes need no deployment, but the next code release must
include the full current source tree in its staging preview.

## Isolation

`aws/staging-host.json` provisions a separate encrypted host, bucket and IAM roles.
There is no production database restore, mail/OAuth credential copy or production
bucket access. Staging requires login, disables signup and all outgoing email, and
uses its own owner account. Its password is held in the encrypted SSM parameter
`/svdex/staging/admin-password`; it is never provided to GitHub. Operators can reset
that staging-only password through SSM and native user tools. The stage script's
fixture vocabulary and company/offering facts never run in production. Do not
enter real investor responses or other customer data in staging.

The external private-access questionnaire is disabled on staging. Native company
and fund applications and private financial forms, when exercised there, only
write to staging. Staging company accounts cannot be used to log in to production.
The preview deliberately uses the same product UI as production, without an extra
banner changing its layout; the staging hostname is the environment indicator.

## Operator setup and recovery

Create the staging stack in the production region with reviewed VPC, subnet and
AMI parameters. The existing GitHub OIDC provider is reused, but the staging role
can only use its own SSM document, instance, code prefix and status receipts. Its
GitHub environment permits only the trusted `staging` branch. Configure staging
variables `SVDEX_DEPLOY_ROLE_ARN`, `SVDEX_ARTIFACT_BUCKET`, `SVDEX_INSTANCE_ID`, and
enable repository variable `SVDEX_STAGING_ENABLED=true` after bootstrap.

Install `aws/deploy-staging-release.sh` root-owned at
`/usr/local/sbin/svdex-deploy-staging-release`, mode 755, and create the host marker
`/var/lib/svdex/staging-host` only on that dedicated host. Configure staging DNS to
its dedicated address. The host helper validates `--staging` bundles and archive
checksums, builds with the pinned upstream launcher, and keeps credentials/logs
private. It never invokes the production installer or production upgrade helper.
Updating that privileged helper remains an operator action.

Successful previews publish a small host-written `deployments/verified.json` with
source tree, commit and completion status. Only the production delivery role can
read this status across environments; it cannot read any staging database or
password. A failed preview cannot promote code. If staging data breaks during a
schema change, repair or rebuild staging; never restore it over production. No
production recovery action is triggered by staging failure.

Both single-host rebuilds may briefly interrupt their respective sites. Staging
has its own running-instance/storage cost. Disable `SVDEX_STAGING_ENABLED` to stop
future preview jobs. Production backups and post-upgrade recovery remain governed
by [production operations](PRODUCTION.md).
