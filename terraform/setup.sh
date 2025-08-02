#!/bin/bash

set -euo pipefail

chmod 600 ~/.ssh/id_rsa
ssh-keyscan github.com >> ~/.ssh/known_hosts

sudo apt update -y
sudo apt upgrade -y

sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

sudo mkdir -p /usr/share/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y
apt-cache policy docker-ce

sudo apt install docker-ce -y

sudo systemctl status docker
sudo systemctl enable docker
sudo usermod -aG docker ${USER}


mkdir -p ~/projects
cd ~/projects

if [ ! -d "docker-compose/.git" ]; then
  echo "Cloning repo..."
  git clone git@github.com:Shoaib720/docker-compose.git
else
  echo "Repo already exists. Pulling latest changes..."
  cd docker-compose
  git reset --hard HEAD
  git clean -fd
  git pull
fi

sudo chmod u+x provision.sh
sudo ./provision.sh