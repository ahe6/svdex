#!/usr/bin/env bash
# Installed by an operator, invoked only through the narrowly scoped SSM document.
# Public CI sees a small S3 receipt, never host logs, backups or app.yml.
set -euo pipefail
release_sha="${1:?source revision required}"
archive_sha="${2:?archive checksum required}"
run_id="${3:?workflow run-attempt required}"
[[ "$release_sha" =~ ^[0-9a-f]{40}$ && "$archive_sha" =~ ^[0-9a-f]{64}$ && "$run_id" =~ ^[0-9]{1,20}-[0-9]{1,5}$ ]] || exit 2
source /etc/svdex-aws.env
export AWS_DEFAULT_REGION
account=$(aws sts get-caller-identity --query Account --output text)
bucket="svdex-discourse-$account-$AWS_DEFAULT_REGION"
release_uri="s3://$bucket/releases/github/$run_id/release.tar.gz"
receipt_uri="s3://$bucket/deployments/github/$run_id.json"
umask 077
work=$(mktemp -d /var/lib/svdex/github-release.XXXXXX)
log="/var/log/svdex-github-$run_id.log"
install -m 600 /dev/null "$log"
status=failed
phase=lock
write_receipt() {
  code=$?
  trap - EXIT
  python3 - "$release_sha" "$run_id" "$status" "$phase" "$work/receipt.json" <<'PY'
import datetime,json,sys
sha,run,status,phase,path=sys.argv[1:]
with open(path,'w') as out:
    json.dump({'source_commit':sha,'run_id':run,'status':status,'phase':phase,'finished_at':datetime.datetime.now(datetime.timezone.utc).isoformat()},out)
PY
  aws s3 cp "$work/receipt.json" "$receipt_uri" --sse AES256 --only-show-errors || true
  echo "SVDEX release $release_sha: $status ($phase). Detailed logs stay private on the host."
  exit "$code"
}
trap write_receipt EXIT
exec 9>/run/svdex-production-deploy.lock
flock -n 9 || exit 1
phase=download
aws s3 cp "$release_uri" "$work/release.tar.gz" --only-show-errors >>"$log" 2>&1
printf '%s  %s\n' "$archive_sha" "$work/release.tar.gz" | sha256sum -c - >>"$log" 2>&1
# Read only the manifest until its kind, commit and cleanliness have been checked.
python3 - "$work/release.tar.gz" "$release_sha" <<'PY' >>"$log" 2>&1
import json,sys,tarfile
with tarfile.open(sys.argv[1]) as archive:
    entry=next(m for m in archive.getmembers() if m.name in ('manifest.json','./manifest.json'))
    manifest=json.load(archive.extractfile(entry))
if manifest['release_kind']!='upgrade' or manifest['hostname']!='svdex.com': raise ValueError('Not an SVDEX code upgrade')
if manifest['source_commit']!=sys.argv[2] or manifest['source_dirty']: raise ValueError('Unexpected source revision')
PY
phase=backup
backup_name="svdex-pre-github-$run_id"
docker exec -u discourse app bash -lc 'cd /var/www/discourse && RAILS_ENV=production bundle exec ruby script/discourse backup "$1" --s3-uploads' -- "$backup_name" >>"$log" 2>&1
backup_path=$(find /var/discourse/shared/standalone/backups/default -maxdepth 1 -name "$backup_name*.tar.gz" -print -quit)
test -n "$backup_path"
backup_sha=$(sha256sum "$backup_path" | cut -d ' ' -f 1)
backup_key="backups/$(basename "$backup_path")"
aws s3 cp "$backup_path" "s3://$bucket/$backup_key" --sse AES256 --checksum-algorithm SHA256 --metadata "sha256=$backup_sha" --only-show-errors >>"$log" 2>&1
aws s3api head-object --bucket "$bucket" --key "$backup_key" > "$work/backup-head.json"
python3 - "$backup_path" "$backup_sha" "$work/backup-head.json" <<'PY' >>"$log" 2>&1
import json,os,sys
head=json.load(open(sys.argv[3]))
if head['ContentLength']!=os.path.getsize(sys.argv[1]) or head['Metadata']['sha256']!=sys.argv[2]: raise ValueError('Backup upload verification failed')
PY
phase=upgrade
# The checked bundle supplies the same preserving upgrade procedure used manually.
tar -xzf "$work/release.tar.gz" -C "$work" ./aws/upgrade-release.sh
bash "$work/aws/upgrade-release.sh" "$release_uri" "$archive_sha" </dev/null >>"$log" 2>&1
phase=verify
curl -fsS --retry 6 --retry-delay 10 --max-time 20 https://svdex.com/srv/status >>"$log" 2>&1
docker exec -u discourse -e SVDEX_PRODUCTION_CHECK=1 app bash -lc 'cd /var/www/discourse && bundle exec rails runner /shared/svdex-release/verify-production.rb' >>"$log" 2>&1
status=success
phase=complete
