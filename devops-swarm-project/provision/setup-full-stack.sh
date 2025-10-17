#!/bin/bash
set -e

echo "[INFO] Checking Docker installation..."
if ! command -v docker &> /dev/null
then
    echo "[INFO] Installing Docker..."
    bash /vagrant/provision/install-docker.sh
fi

echo "[INFO] Checking Swarm status..."
if ! docker info | grep -q "Swarm: active"; then
    echo "[INFO] Initializing Docker Swarm..."
    docker swarm init --advertise-addr 192.168.56.10
else
    echo "[INFO] Swarm already active."
fi

# === Генерация токена всегда, даже если Swarm уже существует ===
echo "[INFO] Generating worker join token..."
docker swarm join-token worker -q > /vagrant/worker-token.txt

# === Развёртывание стека ===
echo "[INFO] Building web-demo image..."
docker build -t web-demo:latest /vagrant/app/web

echo "[INFO] Deploying main stack..."
docker stack deploy -c /vagrant/stack/docker-stack.yml demo_stack

echo "[INFO] Deploying monitoring stack..."
docker stack deploy -c /vagrant/stack/monitoring-stack.yml monitoring

echo "=== FULL STACK DEPLOYED SUCCESSFULLY ==="
echo "Traefik Dashboard: http://192.168.56.10:8080"
echo "Web App: http://192.168.56.10"
echo "Prometheus: http://192.168.56.10:9090"
echo "Grafana: http://192.168.56.10:3000 (admin/admin)"
