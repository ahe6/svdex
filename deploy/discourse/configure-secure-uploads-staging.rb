# frozen_string_literal: true
# Run only on the isolated staging host after deploying aws/secure-uploads.yml.
# Migrate existing uploads with native Discourse tasks after this configuration.
require "json"
require "aws-sdk-s3"
abort "Closed staging only" unless GlobalSetting.hostname == "staging.svdex.com" && SiteSetting.login_required && !SiteSetting.allow_new_registrations && SiteSetting.disable_emails == "yes"
abort "Explicit setup flag required" unless ENV["SVDEX_CONFIGURE_SECURE_UPLOADS"] == "1"
bucket = ENV.fetch("SVDEX_UPLOAD_BUCKET")
abort "Dedicated staging uploads bucket required" unless bucket.match?(/\Asvdex-staging-uploads-\d{12}-us-east-1\z/)
raise "Unexpected existing external store" if SiteSetting.Upload.enable_s3_uploads && SiteSetting.Upload.s3_upload_bucket != bucket
settings = %i[enable_s3_uploads s3_region s3_upload_bucket s3_use_iam_profile s3_use_acls s3_configure_tombstone_policy s3_install_cors_rule secure_uploads secure_uploads_allow_embed_images_in_emails authorized_extensions]
snapshot = ENV.fetch("SVDEX_UPLOAD_SETTINGS_SNAPSHOT", "/shared/svdex-private/staging-upload-settings-before.json")
File.write(snapshot, JSON.pretty_generate(settings.to_h { |key| [key, SiteSetting.public_send(key)] }), mode: "wx", perm: 0o600) unless File.exist?(snapshot)
client = Aws::S3::Client.new(region: "us-east-1", credentials: Aws::InstanceProfileCredentials.new)
client.head_bucket(bucket: bucket)
SiteSetting.s3_use_iam_profile = true
SiteSetting.s3_region = "us-east-1"
SiteSetting.s3_upload_bucket = bucket
SiteSetting.s3_use_acls = true
# Lifecycle is maintained by CloudFormation, not by the application role.
SiteSetting.s3_configure_tombstone_policy = false
SiteSetting.s3_install_cors_rule = false
SiteSetting.enable_s3_uploads = true
SiteSetting.secure_uploads = true
SiteSetting.secure_uploads_allow_embed_images_in_emails = false
SiteSetting.authorized_extensions = (SiteSetting.authorized_extensions.split("|") + ["pdf"]).uniq.join("|")
SiteSetting.svdex_interest_document_uploads_enabled = false if SiteSetting.respond_to?(:svdex_interest_document_uploads_enabled)
puts JSON.generate(host: GlobalSetting.hostname, s3: SiteSetting.Upload.enable_s3_uploads, secure: SiteSetting.secure_uploads,
  secure_images_in_email: SiteSetting.secure_uploads_allow_embed_images_in_emails, pdf: SiteSetting.authorized_extensions.split("|").include?("pdf"),
  intake_enabled: false, store: Discourse.store.class.name)
