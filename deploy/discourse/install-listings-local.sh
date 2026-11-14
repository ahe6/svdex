#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
container=miscdex-forum
docker exec "$container" bash -lc 'test "$(printenv DISCOURSE_HOSTNAME)" = localhost && test "$(printenv DISCOURSE_PORT)" = 4080'
docker exec "$container" rm -rf /var/www/discourse/plugins/discourse-svdex
docker exec "$container" mkdir -p /var/www/discourse/plugins/discourse-svdex
docker cp deploy/discourse/plugins/discourse-svdex/. "$container:/var/www/discourse/plugins/discourse-svdex/"
docker exec "$container" chown -R discourse:discourse /var/www/discourse/plugins/discourse-svdex
# The plugin is copied after the upstream image is built, so its schema must be
# migrated explicitly before any directory or financial workflow can query it.
docker exec -u discourse "$container" bash -lc 'cd /var/www/discourse && bundle exec rake db:migrate'
docker exec -u discourse "$container" bash -lc 'cd /var/www/discourse && bundle exec rails runner '\''Plugin::JsManager.new.compile_js_bundle(Discourse.plugins.find { |p| p.name == "discourse-svdex" }); Stylesheet::Manager.recalculate_fs_asset_cachebuster!'\'''
docker exec -u discourse "$container" bash -lc 'cd /var/www/discourse && SKIP_EMBER_CLI_COMPILE=1 DONT_PRECOMPILE_CSS=1 bundle exec rake assets:precompile'
docker cp deploy/discourse/setup-listings-category.rb "$container:/tmp/svdex-listings-category.rb"
docker exec -u discourse "$container" bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-listings-category.rb'
docker cp deploy/discourse/remove-listing-status-tags.rb "$container:/tmp/svdex-remove-status-tags.rb"
docker exec -u discourse "$container" bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-remove-status-tags.rb'
docker cp deploy/discourse/setup-listing-tag-groups.rb "$container:/tmp/svdex-setup-tag-groups.rb"
docker exec -u discourse "$container" bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-setup-tag-groups.rb'
docker cp deploy/discourse/setup-category-descriptions.rb "$container:/tmp/svdex-category-descriptions.rb"
docker exec -u discourse "$container" bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-category-descriptions.rb'
docker cp deploy/discourse/setup-listing-review.rb "$container:/tmp/svdex-listing-review.rb"
docker exec -u discourse "$container" bash -lc 'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-listing-review.rb'
docker exec "$container" sv restart unicorn
