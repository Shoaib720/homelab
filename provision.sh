#!/bin/bash
docker network create homelab_network
docker compose -f nginx/docker-compose.yml -d
docker compose -f jenkins/docker-compose.yml -d
docker compose -f keycloak/docker-compose.yml -d