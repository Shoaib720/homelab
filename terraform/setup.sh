#!/usr/bin/env bash
set -euo pipefail

#---------------------------
# Helpers
#---------------------------
log() { echo -e "\033[1;32m[SETUP]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
err() { echo -e "\033[1;31m[ERR]\033[0m  $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || (log "Installing $1..." && sudo apt-get install -y "$1"); }

# Determine the “real” user (for EC2 cloud-init or sudo runs)
REAL_USER="${SUDO_USER:-$USER}"

# Non-interactive apt
export DEBIAN_FRONTEND=noninteractive

#---------------------------
# Basic packages & ssh setup
#---------------------------
log "Updating apt cache"
sudo apt-get update -y

need_cmd curl
need_cmd ca-certificates
need_cmd gnupg
need_cmd lsb_release
need_cmd git

# SSH perms (only if files exist)
if [[ -f "/home/$REAL_USER/.ssh/id_rsa" ]]; then
  log "Setting SSH key permissions"
  sudo chmod 600 "/home/$REAL_USER/.ssh/id_rsa"
  sudo chown "$REAL_USER:$REAL_USER" "/home/$REAL_USER/.ssh/id_rsa"
fi

# Add GitHub host key idempotently
log "Adding github.com to known_hosts (idempotent)"
sudo -u "$REAL_USER" bash -c '
  mkdir -p ~/.ssh
  touch ~/.ssh/known_hosts
  ssh-keyscan -t rsa,ecdsa,ed25519 github.com 2>/dev/null | sort -u ~/.ssh/known_hosts - | uniq > ~/.ssh/known_hosts.new
  mv ~/.ssh/known_hosts.new ~/.ssh/known_hosts
'

#---------------------------
# Docker Engine (idempotent)
#---------------------------
if ! dpkg -s docker-ce >/dev/null 2>&1; then
  log "Installing Docker Engine"

  # Add Docker’s official GPG key (idempotent)
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  # Add Docker repo (idempotent)
  UB_CODENAME="$(lsb_release -cs)"
  SOURCE_LINE="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UB_CODENAME} stable"
  if ! grep -Fxq "$SOURCE_LINE" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
    echo "$SOURCE_LINE" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi

  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  log "Docker already installed"
fi

# Enable & start docker (idempotent)
if ! systemctl is-enabled docker >/dev/null 2>&1; then
  log "Enabling docker service"
  sudo systemctl enable docker
fi
if ! systemctl is-active docker >/dev/null 2>&1; then
  log "Starting docker service"
  sudo systemctl start docker
fi

# Add user to docker group (idempotent)
if ! id -nG "$REAL_USER" | grep -qw docker; then
  log "Adding $REAL_USER to docker group"
  sudo usermod -aG docker "$REAL_USER"
  warn "User '$REAL_USER' added to docker group. A re-login or reboot is needed for this to take effect."
fi

#---------------------------
# Projects checkout/update
#---------------------------
log "Preparing projects directory"
sudo -u "$REAL_USER" mkdir -p "/home/$REAL_USER/projects"

REPO_DIR="/home/$REAL_USER/projects/homelab"
REPO_URL="git@github.com:Shoaib720/homelab.git"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  log "Cloning homelab repo"
  sudo -u "$REAL_USER" git clone "$REPO_URL" "$REPO_DIR"
else
  log "Repo exists; fetching latest"
  pushd "$REPO_DIR" >/dev/null
  # Hard reset to remote main to ensure a clean, repeatable state for AMI baking
  sudo -u "$REAL_USER" git fetch --prune
  sudo -u "$REAL_USER" git checkout main
  sudo -u "$REAL_USER" git reset --hard origin/main
  sudo -u "$REAL_USER" git clean -fd
  popd >/dev/null
fi

#---------------------------
# Run provisioner (idempotent friendly)
#---------------------------
if [[ -f "$REPO_DIR/provision.sh" ]]; then
  log "Running provision.sh"
  sudo chmod u+x "$REPO_DIR/provision.sh"
  pushd "$REPO_DIR" >/dev/null
  sudo ./provision.sh
  popd >/dev/null
else
  warn "provision.sh not found at $REPO_DIR; skipping"
fi

log "Setup completed successfully"
