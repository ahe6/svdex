#!/bin/bash
# Run as root on the approved SVDEX host after cloud-init has completed.
set -euo pipefail
release_uri="${1:?Pass the private S3 release URI}"
case "$release_uri" in s3://svdex-discourse-*/releases/*/release.tar.gz) ;; *) echo 'Expected a private SVDEX release URI' >&2; exit 2 ;; esac
test -f /var/lib/svdex/bootstrap-ready
if test -f /var/lib/svdex/site-ready; then
  echo "Initial installation only; preserve the live configuration for upgrades." >&2
  exit 1
fi
umask 022
mkdir -p /var/discourse/shared/standalone/svdex-release
# Redis/PostgreSQL use separate service users and must traverse /shared.
chmod 755 /var/discourse/shared /var/discourse/shared/standalone
aws s3 cp "$release_uri" /var/lib/svdex/release.tar.gz --region us-east-1 --only-show-errors
tar -xzf /var/lib/svdex/release.tar.gz -C /var/discourse/shared/standalone/svdex-release
cd /var/discourse/shared/standalone/svdex-release
python3 - <<'PY_KIND'
import json
kind = json.load(open("manifest.json")).get("release_kind", "installation")
assert kind == "installation", "Code-only upgrade bundles cannot initialize a site"
PY_KIND
mkdir -p sidebar interface
tar -xzf svdex-sidebar.tar.gz -C sidebar
tar -xzf svdex-interface.tar.gz -C interface
install -m 600 app.yml /var/discourse/containers/app.yml
find . -type d -exec chmod 755 {} +
find . -type f ! -name app.yml -exec chmod 644 {} +
chmod 600 app.yml
cd /var/discourse
# Upstream rebuild output can include environment credentials. Keep it private.
install -m 600 /dev/null /var/log/svdex-build.log
./launcher rebuild app > /var/log/svdex-build.log 2>&1
chmod 600 /var/log/svdex-build.log
date -u > /var/lib/svdex/build-ready
printf 'Production image built.\n'
