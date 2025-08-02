#!/bin/bash
if ! docker network inspect homelab_network >/dev/null 2>&1; then
  echo "Creating Docker network: homelab_network"
  docker network create homelab_network
else
  echo "Docker network 'homelab_network' already exists. Skipping."
fi
docker compose -f 01_nginx/docker-compose.yml up -d
docker compose -f 02_keycloak/docker-compose.yml up -d
docker compose -f 03_gitlab/docker-compose.yml up -d
docker compose -f 04_jenkins/docker-compose.yml up -d
docker compose -f 05_sonarqube/docker-compose.yml up -d
docker compose -f 06_portainer/docker-compose.yml up -d
