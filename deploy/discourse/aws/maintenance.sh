#!/bin/bash
# Host-only: the public application container cannot use this instance role.
set -euo pipefail
source /etc/svdex-aws.env
export AWS_DEFAULT_REGION
region="$AWS_DEFAULT_REGION"
bucket="svdex-discourse-$(aws sts get-caller-identity --query Account --output text)-$region"
case "${1:-}" in
  metrics)
    token=$(curl -fsS -X PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' http://169.254.169.254/latest/api/token)
    instance=$(curl -fsS -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id)
    used=$(df --output=pcent / | tail -1 | tr -dc '0-9')
    aws cloudwatch put-metric-data --namespace SVDEX --metric-name DiskUsedPercent --dimensions "InstanceId=$instance" --unit Percent --value "$used"
    if test -f /var/lib/svdex/site-ready; then
      healthy=0
      if curl -fsS --max-time 15 https://svdex.com/srv/status >/dev/null; then healthy=1; fi
      aws cloudwatch put-metric-data --namespace SVDEX --metric-name AppHealthy --dimensions "InstanceId=$instance" --unit Count --value "$healthy"
      age=999
      if test -f /var/lib/svdex/last-backup-upload; then age=$(( ($(date +%s) - $(stat -c %Y /var/lib/svdex/last-backup-upload)) / 3600 )); fi
      aws cloudwatch put-metric-data --namespace SVDEX --metric-name UploadedBackupAgeHours --dimensions "InstanceId=$instance" --unit Count --value "$age"
    fi
    ;;
  backups)
    exec 9>/run/svdex-backup-upload.lock
    flock -n 9 || exit 0
    path=/var/discourse/shared/standalone/backups/default
    test -d "$path" || exit 0
    find "$path" -maxdepth 1 -type f -name '*.tar.gz' -mmin +10 -print0 | while IFS= read -r -d '' file; do
      name=$(basename "$file")
      # Never delete off-server backups when native local retention removes one.
      if ! aws s3api head-object --bucket "$bucket" --key "backups/$name" >/dev/null 2>&1; then
        aws s3 cp "$file" "s3://$bucket/backups/$name" --sse AES256 --only-show-errors
        touch -r "$file" /var/lib/svdex/last-backup-upload
      fi
    done
    ;;
  *) echo 'Usage: svdex-maintenance metrics|backups' >&2; exit 2 ;;
esac
