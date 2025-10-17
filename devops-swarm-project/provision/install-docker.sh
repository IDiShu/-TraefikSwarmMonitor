#!/bin/bash
set -e

echo "[INFO] Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "[INFO] Installing dependencies..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

echo "[INFO] Adding Docker GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "[INFO] Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[INFO] Installing Docker..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[INFO] Adding vagrant user to docker group..."
sudo usermod -aG docker vagrant

echo "[INFO] Checking Docker installation..."
docker --version || echo "Docker not found!"
