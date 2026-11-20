# Native document storage: staging rollout

Private verification conversations use Discourse's native composer, attachments,
post permissions and backups. There is no separate submission/file application.
The capacity review remains a private staff record, independent of the files.

## Infrastructure

`deploy/discourse/aws/secure-uploads.yml` creates a dedicated uploads bucket and
grants only its existing environment host role access to that bucket. Releases and
backups retain their separate buckets and existing permissions. Server-side AES256
encryption and HTTPS are required. CORS is limited to the site's exact origin;
multipart leftovers expire after a day, native tombstones after 30 days. This is
not a financial-document retention policy. Original live attachments have no
automatic expiry and ordinary backup retention still applies.

The pinned Discourse S3 store uses object ACLs: public native assets receive
public-read, protected documents receive private. Accordingly this dedicated
uploads bucket permits ACLs but blocks broad public bucket policies; its only
bucket policy denies insecure transport. Do not copy these settings to the private
backup bucket or add blanket anonymous GetObject access. This configuration must
be tested with both a genuinely private attachment and a public logo/asset.

Discourse uses the host's temporary IAM credentials. Staging's CloudFormation
metadata hop limit is 2 so its Docker container can obtain IMDSv2 credentials;
IMDSv2 remains required and metadata tags stay disabled. The application container
can therefore use that host role: staging PRs must remain explicitly reviewed,
trusted code. No static access keys are stored in Discourse. Production's metadata
configuration is unchanged. See [AWS's container guidance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-IMDS-new-instances.html).

## Staging procedure

1. Deploy the uploads template with Environment=staging, the existing staging
   HostRoleName and SiteOrigin=https://staging.svdex.com. Review the change set.
   Verify the staging host's metadata options permit the application role provider.
2. Take an uploads-inclusive native backup before switching stores. Keep it in
   private encrypted storage. Create `/shared/svdex-private` inside the container,
   owned by discourse with mode 0700.
3. Copy `configure-secure-uploads-staging.rb` to the host and run it as discourse,
   supplying `SVDEX_CONFIGURE_SECURE_UPLOADS=1` and `SVDEX_UPLOAD_BUCKET`. It refuses
   production, open registration, outbound mail and an unexpected existing bucket.
   It keeps a private pre-change settings snapshot, checks bucket access, enables
   native S3/Secure Uploads and PDF, disables secure-image email embedding and
   leaves financial document intake off. CORS/lifecycle stay managed by the stack.
4. Use the pinned native `FileStore::ToS3Migration` with site-setting options,
   `uploads:secure_upload_analyse_and_update` and synchronous
   `uploads:sync_s3_acls[true]`. Inspect migration/analysis logs and existing assets.
   Do not delete the prior local files or the pre-change backup during validation.
5. Run `verify-secure-uploads-staging.rb` with Rails runner **--skip-executor** and
   `SVDEX_VERIFY_SECURE_UPLOADS=1`. It refuses other environments, creates harmless
   temporary documents/accounts and exercises native session, composer upload,
   staff-conversation reply, secure/short links, signed byte downloads, direct S3
   denial, object ACL/encryption and a public-asset comparison. It cleans up its
   temporary records and objects. It never enables mail or uses real statements.
6. Record results and the exact source/settings used. Keep intake closed until a
   matching release, privacy disclosure and retention decision are ready. Do not
   use this script as an automatic production migration.

## Draft attachment authorization

The pinned native helper permits any signed-in user to retrieve an unposted
secure upload when its URL is known and `access_control_post_id` is unset. The
SVDEX `SecureDraftUploads` guard limits that draft state to its uploader and staff.
Posted attachments still use native post/PM authorization; public uploads are
unchanged. The document intake readiness gate requires this guard. The helper is
tracked in upstream contracts so an upstream change prompts review.

## Staging evidence, 2026-11-19

The dedicated bucket and role permissions were applied only to staging. A native
uploads-inclusive backup preceded migration of its 14 existing uploads. Native
S3 migration, secure analysis and ACL synchronization completed successfully.

An isolated Rails probe using the candidate draft guard passed native PDF upload
and trust-level-zero PM attachment, owner/staff download with matching bytes,
guest/outsider secure and short-link denial, unsigned S3 denial, private ACLs,
encryption and continued public asset access. Only harmless disposable files were
used. A native S3-inclusive archive contained the private PDF with matching bytes;
recovering its bytes to a private S3 object preserved them and unsigned retrieval
remained denied. This is file/object recovery, **not** a full database/application
restore. The native CLI adds a version suffix to the requested archive filename;
the probe resolves that generated filename. Private proof archives and the
pre-change backup are retained separately from disposable probe cleanup. The resident staging release has **not** received the candidate guard; this
is probe evidence, not a claim that the deployed application is ready for intake.

## Remaining release work

The local Funds/People and feed changes are not deployed by these storage steps.
The public privacy notice still discourages sensitive-document storage; it must
be revised and approved before requesting real statements. Financial document
intake stays off. No production bucket, file migration or sign-up setting was
changed. A production rollout needs its own backup, migration, permissions and
restore checks; passing a staging probe is not evidence of a production restore.
