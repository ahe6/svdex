#!/bin/bash
# Upgrade the SVDEX plugin/theme while preserving the running site's settings,
# credentials, volumes, pinned Discourse version and registration configuration.
set -euo pipefail
release_uri="${1:?Pass the private S3 release URI}"
case "$release_uri" in s3://svdex-discourse-*/releases/*/release.tar.gz) ;; *) exit 2 ;; esac
test -f /var/lib/svdex/site-ready
umask 077
release_dir=$(mktemp -d /var/lib/svdex/upgrade.XXXXXX)
aws s3 cp "$release_uri" "$release_dir/release.tar.gz" --region us-east-1 --only-show-errors
tar -xzf "$release_dir/release.tar.gz" -C "$release_dir"
# The reduced plugin and native interface must be released together.
test -f "$release_dir/svdex-interface.tar.gz"
# No site-initialization script runs during upgrades. In particular, no content,
# taxonomy, account, badge or signup settings are created/reset here.
previous_image=$(docker inspect --format="{{.Image}}" app)
# The host only needs Docker/Python/AWS CLI. Use Ruby from the pinned app image,
# without starting services or attaching the database/upload volumes.
docker run --rm --network none --entrypoint ruby \
  --mount "type=bind,src=$release_dir,dst=/upgrade" \
  --mount type=bind,src=/var/discourse/containers,dst=/containers \
  "$previous_image" -ryaml -rjson -rfileutils -rbase64 -rdigest -e '
  root = ARGV.fetch(0)
  manifest = JSON.parse(File.read("#{root}/manifest.json"))
  raise "Expected clean SVDEX release" unless manifest["hostname"] == "svdex.com" && !manifest["source_dirty"] && manifest["source_commit"].match?(/\A[0-9a-f]{40}\z/)
  fresh = YAML.load_file("#{root}/app.yml")
  path = "/containers/app.yml"
  live = YAML.load_file(path)
  raise "Unexpected live host/version" unless live.dig("env", "DISCOURSE_HOSTNAME") == "svdex.com" && live.dig("params", "version") == fresh.dig("params", "version")
  source = fresh.fetch("hooks").fetch("after_code").find { |hook| hook.dig("file", "path") == "/tmp/svdex-plugin.tar.gz.b64" }
  target = live.fetch("hooks").fetch("after_code").find { |hook| hook.dig("file", "path") == "/tmp/svdex-plugin.tar.gz.b64" }
  raise "Expected plugin payload" unless source && target
  FileUtils.cp(path, "#{root}/previous-app.yml")
  target["file"]["contents"] = source.fetch("file").fetch("contents")
  File.write(path, YAML.dump(live), perm: 0600)
  puts "Updated plugin payload; live environment preserved."
' /upgrade
# Save theme and configuration rollback material locally before replacing assets.
cp -a /var/discourse/shared/standalone/svdex-release "$release_dir/previous-shared"
printf '%s\n' "$previous_image" > "$release_dir/previous-image.txt"
cd /var/discourse
install -m 600 /dev/null /var/log/svdex-build.log
if ! ./launcher rebuild app > /var/log/svdex-build.log 2>&1; then
  cp "$release_dir/previous-app.yml" containers/app.yml
  docker tag "$previous_image" local_discourse/app
  ./launcher start app >> /var/log/svdex-build.log 2>&1 || true
  echo "Build failed; previous configuration/image restored. See private build log." >&2
  exit 1
fi
shared=/var/discourse/shared/standalone/svdex-release
cp "$release_dir/manifest.json" "$shared/manifest.json"
cp "$release_dir/appearance/common.scss" "$shared/appearance/common.scss"
cp -a "$release_dir/site-pages" "$shared/"
install -m 644 "$release_dir/apply-site-pages.rb" "$shared/apply-site-pages.rb"
install -m 644 "$release_dir/verify-production.rb" "$shared/verify-production.rb"
bash "$release_dir/aws/replace-theme-sources.sh" "$release_dir" "$shared"
find "$shared" -type d -exec chmod 755 {} +
find "$shared" -type f ! -name app.yml -exec chmod 644 {} +
# Native theme import and removal of retired saved links are idempotent.
docker exec -u discourse app bash -lc 'cd /var/www/discourse && bundle exec rails runner '\''
  raise "Expected SVDEX" unless GlobalSetting.hostname == "svdex.com"
  parent = Theme.find(SiteSetting.default_theme_id)
  raise "Expected SVDEX theme" unless parent.name == "SVDEX"
  component = Theme.find_by!(name: "SVDEX Sidebar", component: true)
  imported = RemoteTheme.import_theme_from_directory("/shared/svdex-release/sidebar", theme_id: component.id)
  raise imported.errors.full_messages.join(", ") unless imported.persisted? && imported.errors.empty?
  interface = RemoteTheme.import_theme_from_directory("/shared/svdex-release/interface", theme_id: Theme.find_by(name: "SVDEX Interface", component: true)&.id)
  raise interface.errors.full_messages.join(", ") unless interface.persisted? && interface.errors.empty?
  raise "Interface JavaScript compilation failed" if interface.javascript_cache&.content.to_s.start_with?("throw new Error(")
  parent.child_theme_ids = (parent.child_theme_ids + [interface.id]).uniq
  parent.set_field(target: :common, name: "scss", value: File.read("/shared/svdex-release/appearance/common.scss"))
  parent.save!
  section = SidebarSection.find_by!(section_type: :community, public: true)
  section.sidebar_urls.where(value: ["/companies", "/latest"]).each { |url| section.sidebar_section_links.where(linkable: url).destroy_all }
  puts "Native sidebar and toolbar updated."
'\'''
install -m 644 "$release_dir/configure-upgrade-production.rb" "$shared/configure-upgrade-production.rb"
docker exec -u discourse -e SVDEX_CONFIGURE_UPGRADE=1 app bash -lc 'cd /var/www/discourse && bundle exec rails runner /shared/svdex-release/configure-upgrade-production.rb'
install -m 644 "$release_dir/configure-marketplace.rb" "$shared/configure-marketplace.rb"
docker exec -u discourse -e SVDEX_CONFIGURE_MARKETPLACE=1 app bash -lc 'cd /var/www/discourse && bundle exec rails runner /shared/svdex-release/configure-marketplace.rb'
install -m 644 "$release_dir/retire-information-pages.rb" "$shared/retire-information-pages.rb"
docker exec -u discourse -e SVDEX_RETIRE_INFORMATION_PAGES=1 app bash -lc 'cd /var/www/discourse && bundle exec rails runner /shared/svdex-release/retire-information-pages.rb'
python3 - "$release_dir" <<'PYTHON'
import datetime, hashlib, json, pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
manifest = json.loads((root / "manifest.json").read_text())
shared = pathlib.Path("/var/discourse/shared/standalone/svdex-release")
checked = 0
for name, expected in manifest["files"].items():
    if name.startswith("deploy/discourse/plugins/discourse-svdex/"):
        relative = name.removeprefix("deploy/discourse/plugins/discourse-svdex/")
        data = subprocess.check_output(["docker", "exec", "app", "cat", "/var/www/discourse/plugins/discourse-svdex/" + relative])
    elif name.startswith("frontend/discourse-sidebar/"):
        data = (shared / "sidebar" / name.removeprefix("frontend/discourse-sidebar/")).read_bytes()
    elif name.startswith("frontend/discourse-interface/"):
        data = (shared / "interface" / name.removeprefix("frontend/discourse-interface/")).read_bytes()
    elif name == "frontend/discourse-appearance/common.scss":
        data = (shared / "appearance/common.scss").read_bytes()
    else:
        continue
    assert hashlib.sha256(data).hexdigest() == expected, name
    checked += 1
record_path = pathlib.Path("/var/lib/svdex/deployment.json")
record = json.loads(record_path.read_text()) if record_path.exists() else {}
record.update(source_commit=manifest["source_commit"], verified_source_files=checked,
    image_id=json.loads(subprocess.check_output(["docker", "inspect", "app"]))[0]["Image"],
    runtime_app_sha256=hashlib.sha256(pathlib.Path("/var/discourse/containers/app.yml").read_bytes()).hexdigest(),
    recorded_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
record_path.write_text(json.dumps(record, indent=2) + "\n")
record_path.chmod(0o600)
print("Verified deployed source files:", checked)
PYTHON
printf 'Upgraded release; rollback files: %s\n' "$release_dir"
