#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode=0
if [[ $# -eq 1 && "$1" == --apply ]]; then mode=1
elif [[ $# -ne 0 ]]; then echo 'Usage: scripts/import-company-catalog-local.sh [--apply]' >&2; exit 2
fi
ruby scripts/validate-company-catalog.rb
node scripts/dev-ui.js --assert-stopped
container=miscdex-forum
docker exec "$container" bash -lc 'test "$(printenv DISCOURSE_HOSTNAME)" = localhost && test "$(printenv DISCOURSE_PORT)" = 4080'
docker exec "$container" rm -rf /tmp/svdex-company-catalog-input
docker exec "$container" mkdir -p /tmp/svdex-company-catalog-input
docker cp directory/companies/. "$container:/tmp/svdex-company-catalog-input/"
docker cp deploy/discourse/import-company-catalog-local.rb "$container:/tmp/import-company-catalog-local.rb"
docker exec -u discourse -e "SVDEX_CATALOG_APPLY=$mode" "$container" bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/import-company-catalog-local.rb'
