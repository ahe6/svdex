#!/usr/bin/env bash
# Install from reviewed code, never from the uploaded JSON bundle.
set -euo pipefail
commit="${1:?}"; digest="${2:?}"; run="${3:?}"
[[ "$commit" =~ ^[0-9a-f]{40}$ && "$digest" =~ ^[0-9a-f]{64}$ && "$run" =~ ^[0-9]{1,20}-[0-9]{1,5}$ ]] || exit 2
source /etc/svdex-catalog.env
export AWS_DEFAULT_REGION=us-east-1
[[ "$SVDEX_CATALOG_BUCKET" =~ ^svdex-(discourse|staging)-[0-9]{12}-us-east-1$ ]] || exit 2
[[ "$SVDEX_CATALOG_HOSTNAME" = svdex.com || "$SVDEX_CATALOG_HOSTNAME" = staging.svdex.com ]] || exit 2
umask 077
work=$(mktemp -d /var/lib/svdex/catalog.XXXXXX)
log="/var/log/svdex-catalog-$run.log"
status=failed
finish() {
  result=$?
  trap - EXIT
  python3 - "$commit" "$digest" "$run" "$status" "$work/receipt.json" <<'PY'
import json,sys
sha,digest,run,status,path=sys.argv[1:]
with open(path,'w') as f: json.dump(dict(source_commit=sha,bundle_sha256=digest,run_id=run,status=status),f)
PY
  aws s3 cp "$work/receipt.json" "s3://$SVDEX_CATALOG_BUCKET/catalog/receipts/$run.json" --sse AES256 --only-show-errors || true
  rm -rf "$work"
  exit "$result"
}
trap finish EXIT
# Use the same lock as application delivery, not an unrelated content-only lock.
lock=production
[[ "$SVDEX_CATALOG_HOSTNAME" = staging.svdex.com ]] && lock=staging
exec 9>"/run/svdex-$lock-deploy.lock"
flock -w 900 9 || exit 1
aws s3 cp "s3://$SVDEX_CATALOG_BUCKET/catalog/github/$run/bundle.json" "$work/bundle.json" --only-show-errors >>"$log" 2>&1
printf '%s  %s\n' "$digest" "$work/bundle.json" | sha256sum -c - >>"$log" 2>&1
# The helper already belongs to the installed backend release. No received code
# is copied, evaluated, extracted or run, and no service is rebuilt/restarted.
docker cp "$work/bundle.json" app:/tmp/svdex-public-catalog.json
docker exec app chown discourse:discourse /tmp/svdex-public-catalog.json
docker exec app chmod 600 /tmp/svdex-public-catalog.json
docker exec -u discourse -e "SVDEX_CATALOG_HOSTNAME=$SVDEX_CATALOG_HOSTNAME" -e SVDEX_CATALOG_BUNDLE=/tmp/svdex-public-catalog.json -e SVDEX_CATALOG_APPLY=1 app bash -lc 'cd /var/www/discourse && bundle exec rails runner --skip-executor /shared/svdex-release/import-public-catalog.rb' >>"$log" 2>&1
status=success
