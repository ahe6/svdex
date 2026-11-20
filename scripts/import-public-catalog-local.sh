#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
apply=0
if [[ $# -eq 1 && "$1" == --apply ]]; then apply=1
elif [[ $# -ne 0 ]]; then echo 'Usage: scripts/import-public-catalog-local.sh [--apply]' >&2; exit 2; fi
node scripts/dev-ui.js --assert-stopped
bundle=$(mktemp)
trap 'rm -f "$bundle"' EXIT
ruby scripts/build-public-catalog.rb "$bundle"
docker exec miscdex-forum bash -lc 'test "$DISCOURSE_HOSTNAME" = localhost && test "$DISCOURSE_PORT" = 4080'
docker cp "$bundle" miscdex-forum:/tmp/svdex-public-catalog.json
docker exec miscdex-forum chown discourse:discourse /tmp/svdex-public-catalog.json
docker exec miscdex-forum chmod 600 /tmp/svdex-public-catalog.json
docker cp deploy/discourse/import-public-catalog.rb miscdex-forum:/tmp/svdex-import-public-catalog.rb
docker exec -u discourse -e SVDEX_CATALOG_HOSTNAME=localhost -e SVDEX_CATALOG_BUNDLE=/tmp/svdex-public-catalog.json -e "SVDEX_CATALOG_APPLY=$apply" miscdex-forum bash -lc 'cd /var/www/discourse && bundle exec rails runner --skip-executor /tmp/svdex-import-public-catalog.rb'
