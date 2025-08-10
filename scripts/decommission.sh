#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# Config (tweak if needed)
# ---------------------------
NETWORK_NAME="${NETWORK_NAME:-homelab_network}"
KEEP_NETWORK="${KEEP_NETWORK:-true}"         # set to "false" to remove external network if empty
COMPOSE_FILES=(
  "01_nginx/docker-compose.yml"
  "02_keycloak/docker-compose.yml"
  "03_gitlab/docker-compose.yml"
  "04_jenkins/docker-compose.yml"
  "05_sonarqube/docker-compose.yml"
  "06_portainer/docker-compose.yml"
)

# ---------------------------
# Logging helpers
# ---------------------------
log()  { echo -e "\033[1;34m[DECOMMISSION]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m          $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m         $*"; }

# ---------------------------
# Preconditions
# ---------------------------
if ! command -v docker >/dev/null 2>&1; then
  err "Docker is not installed."
  exit 1
fi

tries=20
until docker info >/dev/null 2>&1; do
  ((tries--)) || { err "Docker daemon did not become ready in time."; exit 1; }
  sleep 1
done

if ! docker compose version >/dev/null 2>&1; then
  err "'docker compose' plugin not found."
  exit 1
fi

# ---------------------------
# Compose tear-down helper
# ---------------------------
down_compose() {
  local yml="$1"
  local dir
  dir="$(dirname "$yml")"

  if [[ ! -f "$yml" ]]; then
    warn "Compose file not found: $yml (skipping)"
    return 0
  fi

  log "Tearing down: $yml"
  (
    cd "$dir"
    # Stop first (faster exit if services are healthy), then down without volumes.
    docker compose -f "$(basename "$yml")" stop || true
    docker compose -f "$(basename "$yml")" down --remove-orphans --timeout 30 || true
    # Explicitly remove any stopped containers for this project (no volumes!)
    docker compose -f "$(basename "$yml")" rm -f || true
  )
}

# ---------------------------
# Decommission stacks (reverse order is safer for deps)
# ---------------------------
for (( idx=${#COMPOSE_FILES[@]}-1 ; idx>=0 ; idx-- )); do
  down_compose "${COMPOSE_FILES[$idx]}"
done

# ---------------------------
# Orphan containers on the homelab network (if any)
# ---------------------------
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  log "Checking for orphan containers on network: $NETWORK_NAME"
  mapfile -t orphans < <(docker ps -a --filter "network=${NETWORK_NAME}" --format '{{.ID}}')
  if [[ ${#orphans[@]} -gt 0 ]]; then
    log "Removing ${#orphans[@]} orphan container(s) from ${NETWORK_NAME}"
    docker rm -f "${orphans[@]}" >/dev/null 2>&1 || true
  else
    log "No orphan containers found on ${NETWORK_NAME}"
  fi
else
  warn "Network '${NETWORK_NAME}' not found. Skipping orphan cleanup."
fi

# ---------------------------
# Optional: remove external network if empty & not kept
# ---------------------------
if [[ "${KEEP_NETWORK}" != "true" ]] && docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  # If no containers are attached, remove it
  if [[ "$(docker network inspect -f '{{json .Containers}}' "$NETWORK_NAME")" == "null" ]]; then
    log "Removing empty network: $NETWORK_NAME"
    docker network rm "$NETWORK_NAME" >/dev/null || true
  else
    warn "Network '$NETWORK_NAME' still has attached containers; not removing."
  fi
else
  log "Keeping external network: $NETWORK_NAME"
fi

# ---------------------------
# Post summary (volumes preserved)
# ---------------------------
log "Containers after teardown:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

log "Docker volumes are preserved. Listing named volumes (for visibility only):"
docker volume ls

log "Decommission complete (volumes NOT removed)."
