# frozen_string_literal: true
# Real native composer + S3 authorization check using harmless disposable files.
# Deliberately excluded from the ordinary local/CI suite and production scripts.
require "aws-sdk-s3"
require "net/http"
require "tempfile"
require "digest"
require "rack/test"
require "zlib"
require "rubygems/package"
abort "Closed staging only" unless GlobalSetting.hostname == "staging.svdex.com" && SiteSetting.login_required && !SiteSetting.allow_new_registrations && SiteSetting.disable_emails == "yes"
abort "Explicit verification flag required" unless ENV["SVDEX_VERIFY_SECURE_UPLOADS"] == "1"
abort "Secure S3 uploads required" unless SiteSetting.Upload.enable_s3_uploads && SiteSetting.secure_uploads && !SiteSetting.secure_uploads_allow_embed_images_in_emails
bucket = SiteSetting.Upload.s3_upload_bucket
abort "Dedicated staging bucket required" unless bucket.match?(/\Asvdex-staging-uploads-\d{12}-us-east-1\z/)
abort "Secure draft guard must be loaded before this probe" unless defined?(DiscourseSvdex::SecureDraftUploads) && UploadsController.ancestors.include?(DiscourseSvdex::SecureDraftUploads)
Middleware::AnonymousCache.disable_anon_cache
def secure_assert!(value, label)
  raise label unless value
  puts "PASS #{label}"
end
def secure_session(user = nil, password = nil)
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.host! "staging.svdex.com"
  app.https!
  app.remote_addr = "198.18.#{SecureRandom.random_number(256)}.#{SecureRandom.random_number(254) + 1}"
  return [app, {}] unless user
  app.get "/session/csrf.json"
  headers = { "X-CSRF-Token" => app.response.parsed_body.fetch("csrf"), "HTTP_ACCEPT" => "application/json", "X-Requested-With" => "XMLHttpRequest" }
  app.post "/session.json", params: { login: user.username, password: password }, headers: headers
  secure_assert!(app.response.status == 200, "native temporary account can sign in")
  [app, headers]
end
def fetch_probe(uri, bucket)
  uri = URI.parse(uri)
  raise "Unexpected object destination" unless uri.scheme == "https" && uri.host.start_with?("#{bucket}.") && uri.host.end_with?(".amazonaws.com")
  Net::HTTP.get_response(uri)
end
def pdf_bytes
  stream = "BT /F1 12 Tf 15 80 Td (SVDEX upload check #{SecureRandom.hex(8)}) Tj ET\n"
  objects = ["<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>", "<< /Length #{stream.bytesize} >>\nstream\n#{stream}endstream", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
  bytes, offsets = +"%PDF-1.4\n", [0]
  objects.each_with_index { |object, index| offsets << bytes.bytesize; bytes << "#{index + 1} 0 obj\n#{object}\nendobj\n" }
  xref = bytes.bytesize
  bytes << "xref\n0 #{offsets.length}\n0000000000 65535 f \n"
  offsets.drop(1).each { |offset| bytes << format("%010d 00000 n \n", offset) }
  bytes << "trailer\n<< /Size #{offsets.length} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
end
users, uploads, keys, files = [], [], [], []
topic = nil
s3 = Aws::S3::Client.new(region: "us-east-1", credentials: Aws::InstanceProfileCredentials.new)
begin
  password = SecureRandom.hex(24)
  %w[owner reviewer outsider].each do |role|
    user = User.create!(username: "uv_#{role}_#{SecureRandom.hex(3)}", email: "#{SecureRandom.hex(8)}@example.invalid", password: password, active: true, approved: true, trust_level: role == "owner" ? 0 : 1, admin: role == "reviewer")
    user.email_tokens.update_all(confirmed: true)
    users << user
  end
  owner, reviewer, outsider = users
  member, headers = secure_session(owner, password)
  staff, = secure_session(reviewer, password)
  other, = secure_session(outsider, password)
  guest, = secure_session
  topic = PostCreator.create!(owner, title: "SVDEX private upload check #{SecureRandom.hex(6)}", raw: "Private attachment verification.", archetype: Archetype.private_message, target_usernames: reviewer.username, skip_validations: true).topic
  file = Tempfile.new(["svdex-upload-check", ".pdf"])
  files << file
  file.binmode; file.write(pdf_bytes); file.flush
  member.post "/uploads.json", params: { upload_type: "composer", for_private_message: "true", file: Rack::Test::UploadedFile.new(file.path, "application/pdf") }, headers: headers
  secure_assert!(member.response.status == 200 && member.response.parsed_body["id"], "a new member uploads a PDF through the native composer endpoint")
  upload = Upload.find(member.response.parsed_body.fetch("id"))
  uploads << upload
  key = URI.parse(upload.url).path.delete_prefix("/")
  keys << key
  secure_assert!(upload.secure?, "financial-conversation attachment is marked secure")
  draft_path = Upload.secure_uploads_url_from_upload_url(upload.url)
  other.get draft_path
  secure_assert!([403, 404].include?(other.response.status), "unposted attachment is not downloadable by an unrelated signed-in member")
  member.post "/posts.json", params: { topic_id: topic.id, raw: "Document attached for private review.\n\n[Attachment](#{upload.short_url})" }, headers: headers
  secure_assert!(member.response.status == 200, "a trust-level-zero member can attach the PDF in an existing staff review conversation")
  reply = Post.find(member.response.parsed_body.fetch("id"))
  upload.reload
  secure_assert!(upload.access_control_post_id == reply.id, "the native private post controls attachment access")
  secure_path = Upload.secure_uploads_url_from_upload_url(upload.url)
  secure_assert!(secure_path.start_with?("/secure-uploads/"), "native attachment URLs use the secure authorization endpoint")
  [member, staff].each do |viewer|
    viewer.get secure_path
    secure_assert!(viewer.response.redirect?, "authorized participant receives a temporary signed download")
    response = fetch_probe(viewer.response.location, bucket)
    secure_assert!(response.code == "200" && Digest::SHA256.hexdigest(response.body) == Digest::SHA256.file(file.path).hexdigest, "authorized download preserves the PDF bytes")
    secure_assert!(!viewer.response.headers["Cache-Control"].to_s.include?("public"), "secure redirects are not publicly cacheable")
  end
  [guest, other].each do |viewer|
    viewer.get secure_path
    blocked = [403, 404].include?(viewer.response.status)
    if viewer.response.redirect?
      uri = URI.parse(viewer.response.location)
      blocked ||= uri.host == "staging.svdex.com" && uri.path.start_with?("/login")
    end
    secure_assert!(blocked, "guest or unrelated member cannot download the private attachment")
    viewer.get Upload.short_path(sha1: upload.sha1, extension: upload.extension)
    secure_assert!([403, 404].include?(viewer.response.status), "short attachment links cannot bypass private-message permissions")
  end
  unsigned = upload.url.start_with?("//") ? "https:#{upload.url}" : upload.url
  secure_assert!(fetch_probe(unsigned, bucket).code == "403", "unsigned direct S3 links cannot retrieve the attachment")
  acl = s3.get_object_acl(bucket: bucket, key: key)
  secure_assert!(acl.grants.none? { |grant| grant.grantee.type == "Group" }, "the stored attachment has no public/group ACL grants")
  secure_assert!(s3.head_object(bucket: bucket, key: key).server_side_encryption == "AES256", "S3 encrypts the stored document")
  public_upload = Upload.where(secure: false).where.not(id: uploads.map(&:id)).where("url LIKE ?", "%#{bucket}%").first
  secure_assert!(public_upload.present?, "migrated public assets remain available for comparison")
  public_url = public_upload.url.start_with?("//") ? "https:#{public_upload.url}" : public_upload.url
  secure_assert!(fetch_probe(public_url, bucket).code == "200", "public native assets remain accessible without making private files public")
  secure_assert!(SiteSetting.disable_emails == "yes" && !SiteSetting.secure_uploads_allow_embed_images_in_emails, "staging mail is disabled and secure images cannot be embedded in notifications")
  if ENV["SVDEX_VERIFY_UPLOAD_BACKUP"] == "1"
    prior = Dir.glob(File.join(BackupRestore::LocalBackupStore.base_directory, "*.{gz,tgz}")).max_by { |path| File.mtime(path) }
    preserved = "/shared/svdex-private/before-secure-uploads-preserved.tar.gz"
    FileUtils.cp(prior, preserved) if prior && !File.exist?(preserved)
    archive = "/shared/svdex-private/secure-upload-proof-#{SecureRandom.hex(4)}.tar.gz"
    success = system(RbConfig.ruby, "script/discourse", "backup", archive, "--s3-uploads", out: "/tmp/svdex-secure-upload-backup.log", err: [:child, :out])
    archive = Dir.glob(archive.delete_suffix(".tar.gz") + "*.tar.gz").max_by { |path| File.mtime(path) }
    secure_assert!(success && archive && File.file?(archive), "native uploads-inclusive backup completes against the S3 store")
    restored = nil
    Zlib::GzipReader.open(archive) do |gzip|
      Gem::Package::TarReader.new(gzip).each do |entry|
        restored = entry.read if entry.file? && entry.full_name.end_with?("/#{upload.sha1}.pdf")
      end
    end
    secure_assert!(restored && Digest::SHA256.hexdigest(restored) == Digest::SHA256.file(file.path).hexdigest, "native archive contains the private PDF with matching bytes")
    restore_key = "restore-probe/#{SecureRandom.hex(12)}.pdf"
    keys << restore_key
    s3.put_object(bucket: bucket, key: restore_key, body: restored, acl: "private", content_type: "application/pdf")
    url = Aws::S3::Presigner.new(client: s3).presigned_url(:get_object, bucket: bucket, key: restore_key, expires_in: 60)
    recovered = fetch_probe(url, bucket)
    secure_assert!(recovered.code == "200" && Digest::SHA256.hexdigest(recovered.body) == Digest::SHA256.hexdigest(restored), "archived document restores to a private S3 object without byte changes")
    secure_assert!(fetch_probe("https://#{bucket}.s3.us-east-1.amazonaws.com/#{restore_key}", bucket).code == "403", "restored evidence remains inaccessible through unsigned object links")
    # Keep the archive private for the normal retention/release review. This is
    # an object/byte recovery test, not a full database/application restore.
  end
ensure
  # All content is disposable and contains no real statement or identity data.
  topic&.destroy!
  uploads.each { |upload| upload.destroy! if upload.persisted? }
  keys.each do |key|
    s3.delete_object(bucket: bucket, key: key)
    s3.delete_object(bucket: bucket, key: "tombstone/#{key}")
  end
  users.reverse_each { |user| user.destroy! if user.persisted? }
  files.each(&:close!)
end
puts "Secure upload checks complete; disposable accounts, conversation and attachment removed."
