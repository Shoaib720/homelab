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
    docker compose -f "$(basename "$yml")" pull --quiet || true
    docker compose -f "$(basename "$yml")" up -d
  )
}

# ---------------------------
# Bring up stacks
# ---------------------------
up_compose "01_nginx/docker-compose.yml"
up_compose "02_keycloak/docker-compose.yml"
# up_compose "03_gitlab/docker-compose.yml"
# up_compose "04_jenkins/docker-compose.yml"
# up_compose "05_sonarqube/docker-compose.yml"
# up_compose "06_portainer/docker-compose.yml"
up_compose "07_vault/docker-compose.yml"

# ---------------------------
# Vault bootstrap (idempotent) - exec inside container (no host port)
# ---------------------------
: "${VAULT_INIT_SHARES:=3}"          # used only for shamir
: "${VAULT_INIT_THRESHOLD:=2}"       # used only for shamir
: "${VAULT_RECOVERY_SHARES:=1}"      # used for auto-unseal (awskms/…)
: "${VAULT_RECOVERY_THRESHOLD:=1}"   # used for auto-unseal (awskms/…)
: "${VAULT_SECRETS_DIR:=./secrets}"
: "${VAULT_MODE_FILE:=${VAULT_SECRETS_DIR}/vault_mode}"   # remembers 'auto' or 'shamir'

# Faster readiness
: "${VAULT_WAIT_TRIES:=30}"        # was 60
: "${VAULT_WAIT_INTERVAL:=1}"      # was 2

# If using instance role, pre-warm IMDS (optional, harmless if not present)
prewarm_imds() {
  docker exec "$VAULT_CONTAINER" sh -lc '
    if command -v curl >/dev/null 2>&1; then
      TOK=$(curl -sS -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)
      [ -n "$TOK" ] && curl -sS -m 1 -H "X-aws-ec2-metadata-token: $TOK" http://169.254.169.254/latest/meta-data/iam/info >/dev/null 2>&1 || true
    fi
  ' >/dev/null 2>&1 || true
}

mkdir -p "$VAULT_SECRETS_DIR"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }
need_cmd jq

# Detect container if not provided
if [[ -z "${VAULT_CONTAINER:-}" ]]; then
  VAULT_CONTAINER="$(docker ps --format '{{.Names}} {{.Image}}' | awk '/hashicorp\/vault/{print $1; exit}')"
fi
if [[ -z "${VAULT_CONTAINER:-}" ]]; then
  warn "Could not auto-detect Vault container (hashicorp/vault). Set VAULT_CONTAINER and re-run."
  return 0 2>/dev/null || exit 0
else
  log "Using Vault container: $VAULT_CONTAINER"
fi

wait_for_vault_json() {
  local tries=60 out
  while (( tries-- )); do
    out="$(docker exec "$VAULT_CONTAINER" sh -lc 'vault status -format=json || true' 2>/dev/null)" || true
    if jq -e '.initialized, .sealed' >/dev/null 2>&1 <<<"$out"; then
      echo "$out"; return 0
    fi
    sleep 2
  done
  return 1
}

latest_init_file() { ls -1t "$VAULT_SECRETS_DIR"/vault_init-*.json 2>/dev/null | head -n1 || true; }

detect_mode_from_file() {
  local f="$1"
  [[ -s "$f" ]] || { echo "unknown"; return 0; }
  if jq -e '.recovery_keys_hex' >/dev/null 2>&1 <"$f"; then echo "auto"; return 0; fi
  if jq -e '.unseal_keys_hex'   >/dev/null 2>&1 <"$f"; then echo "shamir"; return 0; fi
  echo "unknown"
}

remember_mode() { echo -n "$1" > "$VAULT_MODE_FILE"; chmod 600 "$VAULT_MODE_FILE" || true; }
load_mode_hint() { [[ -s "$VAULT_MODE_FILE" ]] && cat "$VAULT_MODE_FILE" || echo "unknown"; }

unseal_with_keys_shamir() {
  local json="$1" threshold="$2"
  for i in $(seq 0 $((threshold-1))); do
    local key
    key="$(jq -r ".unseal_keys_hex[$i]" < "$json")"
    [[ -n "$key" && "$key" != "null" ]] || { err "Missing unseal key index $i in $json"; return 1; }
    docker exec "$VAULT_CONTAINER" sh -lc "vault operator unseal '$key'" >/dev/null
  done
}

bootstrap_vault() {
  log "Waiting for Vault inside container..."
  local st initialized sealed seal_type
  if ! st="$(wait_for_vault_json)"; then
    err "Vault CLI inside container did not become ready in time."
    return 1
  fi

  initialized="$(jq -r '.initialized // false' <<<"$st")"
  sealed="$(jq -r '.sealed // true' <<<"$st")"
  seal_type="$(jq -r '.type // "unknown"' <<<"$st")"   # e.g., shamir, awskms, azurekeyvault…

  if [[ "$initialized" != "true" ]]; then
    warn "Vault is not initialized. Seal type reported: ${seal_type}"
    local tmp_json out mode
    tmp_json="$(mktemp)"

    # Choose init path by seal_type
    if [[ "$seal_type" == "shamir" || "$seal_type" == "unknown" ]]; then
      warn "Running 'vault operator init' with Shamir shares=$VAULT_INIT_SHARES threshold=$VAULT_INIT_THRESHOLD ..."
      if ! docker exec "$VAULT_CONTAINER" sh -lc \
          "vault operator init -key-shares='$VAULT_INIT_SHARES' -key-threshold='$VAULT_INIT_THRESHOLD' -format=json" \
          > "$tmp_json"; then
        err "Vault init failed (Shamir path)."; rm -f "$tmp_json"; return 1
      fi
    else
      warn "Running 'vault operator init' with RECOVERY shares=$VAULT_RECOVERY_SHARES threshold=$VAULT_RECOVERY_THRESHOLD (auto-unseal)..."
      if ! docker exec "$VAULT_CONTAINER" sh -lc \
          "vault operator init -recovery-shares='$VAULT_RECOVERY_SHARES' -recovery-threshold='$VAULT_RECOVERY_THRESHOLD' -format=json" \
          > "$tmp_json"; then
        err "Vault init failed (auto-unseal path)."; rm -f "$tmp_json"; return 1
      fi
    fi

    out="$VAULT_SECRETS_DIR/vault_init-$(date +%Y%m%d-%H%M%S).json"
    mv "$tmp_json" "$out"; chmod 600 "$out"
    warn "Saved init artifacts to $out (chmod 600). Keep this SAFE."

    # Decide mode from the file and remember (never guess later)
    mode="$(detect_mode_from_file "$out")"
    remember_mode "$mode"

    if [[ "$mode" == "shamir" ]]; then
      log "Unsealing Vault with Shamir keys (threshold=$VAULT_INIT_THRESHOLD)..."
      unseal_with_keys_shamir "$out" "$VAULT_INIT_THRESHOLD"
    elif [[ "$mode" == "auto" ]]; then
      warn "Restarting Vault container to trigger auto-unseal..."
      docker restart "$VAULT_CONTAINER" >/dev/null
      # bounded wait for initialized+unsealed
      local tries=60
      while (( tries-- )); do
        st="$(docker exec "$VAULT_CONTAINER" sh -lc 'vault status -format=json || true' 2>/dev/null)"
        if jq -e '.initialized and (.sealed|not)' >/dev/null 2>&1 <<<"$st"; then
          log "Vault unsealed via auto-unseal."
          break
        fi
        echo -n "."
        sleep 2
      done
      echo
      if [[ -z "${st:-}" || "$(jq -r '.sealed // true' <<<"${st:-{}}")" == "true" ]]; then
        err "Vault remains sealed after restart. Check KMS permissions/region/network; see container logs."
        return 1
      fi
    else
      warn "Could not determine mode from init file; not attempting unseal automatically."
    fi

    # Optional: store root token if present
    jq -r '.root_token // empty' < "$out" > "$VAULT_SECRETS_DIR/root_token" || true
    [[ -s "$VAULT_SECRETS_DIR/root_token" ]] && chmod 600 "$VAULT_SECRETS_DIR/root_token" && \
      warn "Root token stored at $VAULT_SECRETS_DIR/root_token (chmod 600). Consider moving to a secure store."
    log "Vault initialized."
  fi

  # Post-init: ensure unsealed based on remembered mode (don’t mis-detect)
  local mode_hint init_file
  mode_hint="$(load_mode_hint)"
  st="$(wait_for_vault_json)" || true
  sealed="$(jq -r '.sealed // true' <<<"${st:-{}}")"

  if [[ "$sealed" == "true" ]]; then
    init_file="$(latest_init_file)"
    if [[ "$mode_hint" == "auto" ]] || [[ "$(detect_mode_from_file "$init_file")" == "auto" ]]; then
      warn "Vault is initialized but sealed (auto-unseal). Restarting container to trigger auto-unseal..."
      docker restart "$VAULT_CONTAINER" >/dev/null
      st="$(wait_for_vault_json)" || true
      if [[ "$(jq -r '.sealed // true' <<<"${st:-{}}")" == "true" ]]; then
        err "Vault remains sealed after restart; check KMS permissions/region/network."
        return 1
      fi
      log "Vault unsealed via auto-unseal."
    else
      warn "Vault is initialized but sealed (Shamir). Attempting unseal from saved keys..."
      init_file="$(latest_init_file)"
      if [[ -z "$init_file" ]]; then
        err "No saved init file found in $VAULT_SECRETS_DIR; cannot unseal automatically."
        return 1
      fi
      unseal_with_keys_shamir "$init_file" "$VAULT_INIT_THRESHOLD"
      log "Vault unsealed."
    fi
  else
    log "Vault initialized and unsealed."
  fi
}

# Run bootstrap
if [[ -n "${VAULT_CONTAINER:-}" ]]; then
  bootstrap_vault
else
  warn "Skipping Vault bootstrap because container is unknown."
fi


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
