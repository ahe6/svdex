#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
container=miscdex-forum
docker exec "$container" bash -lc 'test "$(printenv DISCOURSE_HOSTNAME)" = localhost && test "$(printenv DISCOURSE_PORT)" = 4080'
docker cp deploy/discourse/verify-production.rb "$container:/tmp/svdex-production-smoke.rb"
docker cp deploy/discourse/native-defaults.rb "$container:/tmp/native-defaults.rb"
docker cp deploy/discourse/configure-upgrade-production.rb "$container:/tmp/configure-upgrade-production.rb"
docker cp deploy/discourse/site-pages/. "$container:/tmp/svdex-site-pages/"
docker cp deploy/discourse/apply-site-pages.rb "$container:/tmp/apply-site-pages.rb"
docker cp deploy/discourse/native-workflow-check-helper.rb "$container:/tmp/native-workflow-check-helper.rb"
docker exec "$container" mkdir -p /tmp/svdex-prototypes
docker cp deploy/discourse/prototypes/private-access-workflow.rb "$container:/tmp/svdex-prototypes/private-access-workflow.rb"
docker cp deploy/discourse/upstream-contracts.json "$container:/tmp/svdex-upstream-contracts.json"
failed=()
for script in verify-upstream-contracts-local verify-category-navigation-local verify-companies-local verify-people-directory-local verify-company-financials-local verify-organization-metadata-local verify-listings-local verify-listing-financial-fields-local verify-listing-valuation-local verify-company-search-local verify-listing-review-local verify-member-flows-local verify-community-categories-local verify-help-feeds-local verify-private-offerings-local verify-events-local verify-production-configuration-local verify-site-pages-local verify-interface-theme-local verify-native-workflows-local verify-native-company-fields-local verify-marketplace-flows-local verify-offering-structure-local verify-company-updates-local verify-public-interest-local verify-offering-bids-local verify-my-interest-local verify-production-smoke-local; do
  docker cp "deploy/discourse/$script.rb" "$container:/tmp/$script.rb"
  if ! docker exec -u discourse "$container" bash -lc "cd /var/www/discourse && bundle exec rails runner --skip-executor /tmp/$script.rb"; then
    failed+=("$script")
  fi
done
if (( ${#failed[@]} )); then
  printf 'Failed native checks: %s\n' "${failed[*]}" >&2
  exit 1
fi
