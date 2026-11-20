#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 1 || ! "$1" =~ ^[1-9][0-9]*$ ]]; then echo 'Usage: scripts/export-company-correction-local.sh TOPIC_ID' >&2; exit 2; fi
node scripts/dev-ui.js --assert-stopped
container=miscdex-forum
docker exec "$container" bash -lc 'test "$(printenv DISCOURSE_HOSTNAME)" = localhost && test "$(printenv DISCOURSE_PORT)" = 4080'
docker cp deploy/discourse/export-company-correction-local.rb "$container:/tmp/export-company-correction-local.rb"
docker exec -u discourse -e "SVDEX_CORRECTION_TOPIC=$1" "$container" bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/export-company-correction-local.rb'
mkdir -p work/company-corrections
docker cp "$container:/tmp/svdex-company-correction.json" "work/company-corrections/$1.json"
printf 'Review work/company-corrections/%s.json before copying approved changes into directory/companies/.\n' "$1"
