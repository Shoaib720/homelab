#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# Logging helpers
# ---------------------------
log()  { echo -e "\033[1;32m[PROVISION]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m       $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m      $*"; }

# ---------------------------
# Preconditions
# ---------------------------
if ! command -v docker >/dev/null 2>&1; then
  err "Docker is not installed."
  exit 1
fi

# Wait for Docker daemon (useful on first boot)
tries=20
until docker info >/dev/null 2>&1; do
  ((tries--)) || { err "Docker daemon did not become ready in time."; exit 1; }
  sleep 1
done

# Check compose plugin
if ! docker compose version >/dev/null 2>&1; then
  err "'docker compose' plugin not found."
  exit 1
fi

# ---------------------------
# Network (idempotent)
# ---------------------------
NETWORK_NAME="homelab_network"
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  log "Creating docker network: $NETWORK_NAME"
  docker network create --driver bridge --attachable "$NETWORK_NAME" >/dev/null
else
  log "Docker network '$NETWORK_NAME' exists. Skipping."
fi

# ---------------------------
# Compose bring-up helper
# ---------------------------
up_compose() {
  local yml="$1"
  local dir
  dir="$(dirname "$yml")"

  if [[ ! -f "$yml" ]]; then
    warn "Compose file not found: $yml (skipping)"
    return 0
  fi

  log "Bringing up: $yml"
  (
    cd "$dir"
    # Pull latest images (safe/idempotent), prune orphans, and detach
    docker compose -f "$(basename "$yml")" pull --quiet || true
    docker compose -f "$(basename "$yml")" up -d
  )
}

# ---------------------------
# Bring up stacks
# (order chosen so core IAM/CI are up early; reverse proxy can be first or last per your wiring)
# ---------------------------
up_compose "01_nginx/docker-compose.yml"
up_compose "02_keycloak/docker-compose.yml"
up_compose "03_gitlab/docker-compose.yml"
up_compose "04_jenkins/docker-compose.yml"
up_compose "05_sonarqube/docker-compose.yml"
up_compose "06_portainer/docker-compose.yml"

# ---------------------------
# Basic post-checks
# ---------------------------
log "Active containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Optional: simple health summary (ignores containers without HEALTHCHECK)
if docker ps --format '{{.Names}}' | grep -q .; then
  log "Health state (if defined):"
  docker ps --format '{{.Names}}' | while read -r c; do
    hs=$(docker inspect --format='{{json .State.Health}}' "$c" 2>/dev/null || true)
    if [[ -n "$hs" && "$hs" != "null" ]]; then
      status=$(echo "$hs" | sed -n 's/.*"Status":"\([^"]*\)".*/\1/p')
      echo " - $c: ${status}"
    fi
  done
fi

log "Provision complete."
