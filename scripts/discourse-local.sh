#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
checkout="$repo_dir/.data/discourse-docker"
upstream_ref=1309ec425ab697996a33b931e309df95c1fbd981
config=miscdex-forum
command_name="${1:-status}"

case "$command_name" in
  setup)
    docker info >/dev/null
    # These upstream images are public. Avoid depending on a desktop keychain prompt.
    docker_endpoint="${DOCKER_HOST:-$(docker context inspect --format '{{.Endpoints.docker.Host}}')}"
    client_config="$repo_dir/.data/discourse-docker-client"
    mkdir -p "$client_config"
    printf '%s\n' '{"auths":{}}' > "$client_config/config.json"
    chmod 600 "$client_config/config.json"
    export DOCKER_HOST="$docker_endpoint" DOCKER_CONFIG="$client_config"
    docker network inspect miscdex-discourse >/dev/null 2>&1 || docker network create miscdex-discourse
    if docker container inspect miscdex-discourse-mail >/dev/null 2>&1; then
      docker start miscdex-discourse-mail >/dev/null
    else
      docker run -d --name miscdex-discourse-mail --restart unless-stopped \
        --network miscdex-discourse -p 127.0.0.1:4081:8025 \
        -e MP_DATABASE=/data/mailpit.db -e MP_MAX_MESSAGES=500 \
        -v miscdex-discourse-mail-data:/data axllent/mailpit:v1.33.1
    fi
    if [[ ! -d "$checkout/.git" ]]; then
      mkdir -p "$repo_dir/.data"
      git clone https://github.com/discourse/discourse_docker.git "$checkout"
      git -C "$checkout" checkout "$upstream_ref"
    fi
    if [[ "$(git -C "$checkout" rev-parse HEAD)" != "$upstream_ref" ]]; then
      echo 'The Discourse Docker checkout differs from the recorded revision. Review it before rebuilding.' >&2
      exit 1
    fi
    git -C "$checkout" checkout --detach "$upstream_ref"
    install -m 600 "$repo_dir/deploy/discourse/local.yml" "$checkout/containers/$config.yml"
    base_image="$(sed -n 's/^base_image: *//p' "$checkout/templates/web.template.yml")"
    if ! docker image inspect "$base_image" >/dev/null 2>&1; then
      docker pull "$base_image"
    fi
    # The engine runs Linux on Docker Desktop; the upstream host checks assume Linux.
    if [[ "$(uname -s)" == Darwin ]]; then
      "$checkout/launcher" rebuild "$config" --skip-prereqs
    else
      "$checkout/launcher" rebuild "$config"
    fi
    "$0" configure
    "$0" listings
    "$0" community
    "$0" help
    "$0" companies
    "$0" chat
    "$0" appearance
    "$0" achievements
    "$0" private-offerings
    "$0" events
    "$0" marketplace
    ;;
  configure)
    python3 - "$repo_dir" <<'PYTHON'
import json, os, pathlib, secrets, subprocess, sys, time, urllib.request
root = pathlib.Path(sys.argv[1])
credentials_path = root / ".data/discourse-local-admin.json"
if credentials_path.exists():
    credentials = json.loads(credentials_path.read_text())
else:
    credentials = {"url": "http://localhost:4080", "username": "svdex",
                   "email": "admin@miscdex.com", "password": secrets.token_urlsafe(32)}
    fd = os.open(credentials_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as target:
        json.dump(credentials, target, indent=2)
for attempt in range(60):
    try:
        with urllib.request.urlopen("http://127.0.0.1:4080", timeout=5):
            break
    except OSError:
        if attempt == 59:
            raise SystemExit("Discourse has not become ready; inspect its logs.")
        time.sleep(2)
subprocess.run(["docker", "cp", str(root / "deploy/discourse/configure-local.rb"),
                "miscdex-forum:/tmp/miscdex-configure-local.rb"], check=True)
subprocess.run(["docker", "cp", str(root / "assets/brand/svdex-wordmark.svg"),
                "miscdex-forum:/tmp/svdex-wordmark.svg"], check=True)
subprocess.run(["docker", "exec", "-i", "-u", "discourse", "miscdex-forum", "bash", "-lc",
                "cd /var/www/discourse && bundle exec rails runner /tmp/miscdex-configure-local.rb"],
               input=credentials["password"], text=True, check=True)
print("Discourse: http://localhost:4080")
print("Admin credentials: " + str(credentials_path))
PYTHON
    ;;
  events)
    docker cp "$repo_dir/deploy/discourse/setup-events-local.rb" "$config:/tmp/svdex-events-local.rb"
    docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-events-local.rb'
    "$0" theme
    ;;
  theme)
    docker exec "$config" rm -rf /tmp/miscdex-sidebar
    docker cp "$repo_dir/frontend/discourse-sidebar" "$config:/tmp/miscdex-sidebar"
    docker cp "$repo_dir/deploy/discourse/install-sidebar.rb" "$config:/tmp/miscdex-install-sidebar.rb"
    docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/miscdex-install-sidebar.rb'
    docker exec "$config" rm -rf /tmp/miscdex-interface
    docker exec "$config" mkdir -p /tmp/miscdex-interface
    docker cp "$repo_dir/frontend/discourse-interface/." "$config:/tmp/miscdex-interface/"
    docker cp "$repo_dir/deploy/discourse/install-interface.rb" "$config:/tmp/svdex-install-interface.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-install-interface.rb'
    ;;
  community)
    docker cp "$repo_dir/deploy/discourse/consolidate-community-categories.rb" "$config:/tmp/svdex-consolidate-categories.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-consolidate-categories.rb'
    ;;
  companies)
    docker cp "$repo_dir/deploy/discourse/setup-company-accounts.rb" "$config:/tmp/svdex-company-accounts.rb"
    docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-company-accounts.rb'
    docker cp "$repo_dir/deploy/discourse/setup-company-financials-local.rb" "$config:/tmp/svdex-company-financials.rb"
    docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-company-financials.rb'
    "$0" fund
    "$0" theme
    ;;
  fund)
    docker cp "$repo_dir/deploy/discourse/setup-fund-local.rb" "$config:/tmp/svdex-fund-local.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-fund-local.rb'
    ;;
  introductions|marketplace)
    docker cp "$repo_dir/deploy/discourse/configure-marketplace.rb" "$config:/tmp/svdex-marketplace.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-marketplace.rb'
    ;;
  help)
    docker cp "$repo_dir/deploy/discourse/setup-help-category.rb" "$config:/tmp/svdex-help-category.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-help-category.rb'
    ;;
  achievements)
    docker cp "$repo_dir/deploy/discourse/setup-achievements.rb" "$config:/tmp/svdex-achievements.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-achievements.rb'
    ;;
  private-offerings)
    "$0" achievements
    docker cp "$repo_dir/deploy/discourse/setup-private-offerings-local.rb" "$config:/tmp/svdex-private-offerings.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/svdex-private-offerings.rb'
    ;;
  chat)
    docker cp "$repo_dir/deploy/discourse/setup-chat.rb" "$config:/tmp/miscdex-setup-chat.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/miscdex-setup-chat.rb'
    ;;
  appearance)
    "$0" theme
    docker exec "$config" mkdir -p /tmp/miscdex-appearance
    docker cp "$repo_dir/frontend/discourse-appearance/." "$config:/tmp/miscdex-appearance/"
    docker cp "$repo_dir/assets/brand/svdex-wordmark.svg" "$config:/tmp/miscdex-appearance/wordmark.svg"
    docker cp "$repo_dir/deploy/discourse/install-appearance.rb" "$config:/tmp/miscdex-install-appearance.rb"
    exec docker exec -u discourse "$config" bash -lc \
      'cd /var/www/discourse && bundle exec rails runner /tmp/miscdex-install-appearance.rb'
    ;;
  listings)
    "$repo_dir/deploy/discourse/install-listings-local.sh"
    "$0" theme
    ;;
  start|stop|restart|logs)
    case "$command_name" in
      start) docker start miscdex-discourse-mail >/dev/null; exec docker start "$config" ;;
      stop) docker stop "$config"; exec docker stop miscdex-discourse-mail ;;
      restart) docker start miscdex-discourse-mail >/dev/null; exec docker restart "$config" ;;
      logs) exec docker logs --tail 150 -f "$config" ;;
    esac
    ;;
  status)
    docker ps -a --filter "name=^/$config$" --filter 'name=^/miscdex-discourse-mail$' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    ;;
  *) echo 'Usage: scripts/discourse-local.sh setup|configure|theme|appearance|achievements|private-offerings|events|chat|community|introductions|marketplace|help|companies|fund|listings|start|stop|restart|logs|status' >&2; exit 2 ;;
esac
