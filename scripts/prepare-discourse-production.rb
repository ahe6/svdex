# frozen_string_literal: true
# Generates private files only. Does not provision, deploy, change DNS or send mail.
require "json"
require "yaml"
require "base64"
require "digest"
require "fileutils"
require "open3"
require "tmpdir"

abort "Usage: ruby scripts/prepare-discourse-production.rb PRIVATE_CONFIG.json|--upgrade|--staging OUTPUT_DIRECTORY" unless ARGV.size == 2
root = File.expand_path("..", __dir__)
staging = ARGV.first == "--staging"
upgrade_only = ARGV.first == "--upgrade" || staging
output_path = File.expand_path(ARGV.last)
if upgrade_only
  # Code-only updates never need SMTP/OAuth credentials or a production export.
  config = JSON.parse(File.read("#{root}/deploy/discourse/production.json.example"))
  config["hostname"] = "staging.svdex.com" if staging
else
  config_path = File.expand_path(ARGV.first)
  abort "Private configuration must have permissions 600" unless (File.stat(config_path).mode & 0o777) == 0o600
  config = JSON.parse(File.read(config_path))
end
required = upgrade_only ? %w[hostname discourse_revision docker_revision] : %w[hostname admin_email notification_email smtp_address smtp_user_name smtp_password discourse_revision docker_revision]
required.each { |key| abort "Missing configuration: #{key}" unless config[key].is_a?(String) && !config[key].strip.empty? }
abort "Expected a public hostname" unless config["hostname"].match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+\z/) && !config["hostname"].end_with?(".invalid", ".localhost")
unless upgrade_only
  %w[admin_email notification_email].each do |key|
    abort "Invalid #{key}" unless config[key].match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/) && !config[key].end_with?(".invalid")
  end
  abort "SMTP port must be 587 (STARTTLS)" unless config.fetch("smtp_port", 587) == 587
  abort "SMTP hostname is invalid" unless config["smtp_address"].match?(/\A[a-zA-Z0-9.-]+\z/) && config["smtp_address"].include?(".")
end
%w[discourse_revision docker_revision].each do |key|
  abort "#{key} must be an immutable Git commit" unless config[key].match?(/\A[0-9a-f]{40}\z/)
end
abort "Output directory already exists" if File.exist?(output_path)

plugin = "deploy/discourse/plugins/discourse-svdex"
# Do not ship stale generated presentation when the editable style modules changed.
_, error, style_status = Open3.capture3("node", "#{root}/scripts/build-styles.js", "--check")
abort "Appearance build is stale: #{error}" unless style_status.success?
source_dirs = [plugin, "frontend/discourse-sidebar", "frontend/discourse-interface", "frontend/discourse-appearance", "assets/brand", "deploy/discourse/aws", "deploy/discourse/site-pages"]
sources = (source_dirs.flat_map { |path| Dir.glob("#{root}/#{path}/**/*").select { |entry| File.file?(entry) && !entry.include?("/__pycache__/") } } + %w[native-defaults.rb configure-production.rb configure-upgrade-production.rb configure-marketplace.rb retire-information-pages.rb apply-site-pages.rb verify-production.rb].map { |name| "#{root}/deploy/discourse/#{name}" }).sort
sources << "#{root}/deploy/discourse/configure-staging.rb" if staging
plugin_archive, status = Open3.capture2({ "COPYFILE_DISABLE" => "1" }, "tar", "-czf", "-", "-C", "#{root}/deploy/discourse/plugins", "discourse-svdex")
abort "Could not package plugin" unless status.success?
files = sources.to_h { |path| [path.delete_prefix("#{root}/"), Digest::SHA256.file(path).hexdigest] }
head, status = Open3.capture2("git", "-C", root, "rev-parse", "HEAD")
abort "Could not identify source revision" unless status.success?
tree, = Open3.capture2("git", "-C", root, "rev-parse", "HEAD^{tree}")
dirty, = Open3.capture2("git", "-C", root, "status", "--porcelain")

app = if upgrade_only
  { "params" => { "version" => config.fetch("discourse_revision") },
    "hooks" => { "after_code" => [
      { "file" => { "path" => "/tmp/svdex-plugin.tar.gz.b64", "contents" => Base64.strict_encode64(plugin_archive), "chmod" => "600" } },
    ] } }
else
{
  "templates" => %w[postgres redis web web.ratelimited web.ssl web.letsencrypt.ssl].map { |name| "templates/#{name}.template.yml" },
  "expose" => ["80:80", "443:443"],
  "params" => { "version" => config.fetch("discourse_revision") },
  "env" => {
    "LANG" => "en_US.UTF-8", "LC_ALL" => "en_US.UTF-8",
    "DISCOURSE_HOSTNAME" => config.fetch("hostname"),
    "DISCOURSE_DEVELOPER_EMAILS" => config.fetch("admin_email"),
    "DISCOURSE_NOTIFICATION_EMAIL" => config.fetch("notification_email"),
    "DISCOURSE_SMTP_ADDRESS" => config.fetch("smtp_address"),
    "DISCOURSE_SMTP_PORT" => 587,
    "DISCOURSE_SMTP_USER_NAME" => config.fetch("smtp_user_name"),
    "DISCOURSE_SMTP_PASSWORD" => config.fetch("smtp_password"),
    "DISCOURSE_SMTP_ENABLE_START_TLS" => true,
    "DISCOURSE_SMTP_OPENSSL_VERIFY_MODE" => "peer",
    "DISCOURSE_FORCE_HTTPS" => true,
    "DISCOURSE_ALLOW_NEW_REGISTRATIONS" => false,
    "DISCOURSE_LOGIN_REQUIRED" => true,
    "DISCOURSE_TITLE" => "SVDEX",
    "LETSENCRYPT_ACCOUNT_EMAIL" => config.fetch("admin_email"),
  },
  "volumes" => [
    { "volume" => { "host" => "/var/discourse/shared/standalone", "guest" => "/shared" } },
    { "volume" => { "host" => "/var/discourse/shared/standalone/log/var-log", "guest" => "/var/log" } },
  ],
  "hooks" => { "after_code" => [
    { "file" => { "path" => "/tmp/svdex-plugin.tar.gz.b64", "contents" => Base64.strict_encode64(plugin_archive), "chmod" => "600" } },
    { "exec" => { "cmd" => [
      "base64 --decode /tmp/svdex-plugin.tar.gz.b64 | tar -xz -C /var/www/discourse/plugins",
      "chown -R discourse:www-data /var/www/discourse/plugins/discourse-svdex",
      "rm /tmp/svdex-plugin.tar.gz.b64",
    ] } },
  ] },
}

end

FileUtils.mkdir_p(output_path, mode: 0o700)
File.chmod(0o700, output_path)
File.write("#{output_path}/app.yml", YAML.dump(app), perm: 0o600)
File.write("#{output_path}/manifest.json", JSON.pretty_generate({
  release_kind: staging ? "staging" : upgrade_only ? "upgrade" : "installation",
  hostname: config.fetch("hostname"), source_commit: head.strip, source_tree: tree.strip, source_dirty: !dirty.empty?,
  discourse_revision: config.fetch("discourse_revision"), docker_revision: config.fetch("docker_revision"),
  files: files, app_sha256: Digest::SHA256.file("#{output_path}/app.yml").hexdigest,
}) + "\n", perm: 0o600)
abort "Could not package sidebar" unless system({ "COPYFILE_DISABLE" => "1" }, "tar", "-czf", "#{output_path}/svdex-sidebar.tar.gz", "-C", "#{root}/frontend/discourse-sidebar", ".")
abort "Could not package interface" unless system({ "COPYFILE_DISABLE" => "1" }, "tar", "-czf", "#{output_path}/svdex-interface.tar.gz", "-C", "#{root}/frontend/discourse-interface", ".")
FileUtils.cp_r("#{root}/frontend/discourse-appearance", "#{output_path}/appearance")
FileUtils.cp_r("#{root}/assets/brand", "#{output_path}/brand")
FileUtils.cp_r("#{root}/deploy/discourse/site-pages", "#{output_path}/site-pages")
%w[native-defaults.rb configure-production.rb configure-upgrade-production.rb configure-marketplace.rb retire-information-pages.rb apply-site-pages.rb verify-production.rb].each do |name|
  FileUtils.cp("#{root}/deploy/discourse/#{name}", "#{output_path}/#{name}")
end
if staging
  FileUtils.cp("#{root}/deploy/discourse/configure-staging.rb", "#{output_path}/configure-staging.rb")
  File.write("#{output_path}/staging-plugin.b64", Base64.strict_encode64(plugin_archive), perm: 0o600)
end
FileUtils.mkdir_p("#{output_path}/aws")
Dir.glob("#{root}/deploy/discourse/aws/*").select { |path| File.file?(path) }.each { |path| FileUtils.cp(path, "#{output_path}/aws/") }
puts(staging ? "Prepared isolated staging assets with no production credentials." : upgrade_only ? "Prepared credential-free upgrade assets; live configuration is preserved." : "Prepared private installation configuration; registration and anonymous access remain closed.")
puts "No services were deployed."
warn "Source contains uncommitted changes; commit and regenerate before release." unless dirty.empty?
