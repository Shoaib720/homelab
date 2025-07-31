#!/bin/bash
if ! docker network inspect homelab_network >/dev/null 2>&1; then
  echo "Creating Docker network: homelab_network"
  docker network create homelab_network
else
  echo "Docker network 'homelab_network' already exists. Skipping."
fi
docker compose -f nginx/docker-compose.yml up -d
docker compose -f jenkins/docker-compose.yml up -d
docker compose -f keycloak/docker-compose.yml up -d