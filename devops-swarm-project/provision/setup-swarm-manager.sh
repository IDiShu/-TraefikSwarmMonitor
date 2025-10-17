#!/bin/bash
set -e

# -----------------------------
# 1. Установка Docker (если ещё не установлен)
# -----------------------------
if ! command -v docker &> /dev/null
then
    bash /vagrant/provision/install-docker.sh
fi

# -----------------------------
# 2. Инициализация Swarm (если ещё не инициализировано)
# -----------------------------
if ! docker info | grep -q "Swarm: active"; then
    docker swarm init --advertise-addr 192.168.56.10
fi

# -----------------------------
# 3. Сохраняем токен worker для автоматизации
# -----------------------------
# Этот файл будет доступен на всех VM через /vagrant
docker swarm join-token worker -q > /vagrant/worker-token.txt

# -----------------------------
# 4. Деплой веб-приложения + Traefik
# -----------------------------
docker stack deploy -c /vagrant/stack/docker-stack.yml demo_stack

# -----------------------------
# 5. Деплой мониторинга (Prometheus + Grafana)
# -----------------------------
docker stack deploy -c /vagrant/stack/monitoring-stack.yml monitoring

echo "=== FULL STACK DEPLOYED SUCCESSFULLY ==="
echo "Traefik Dashboard: http://192.168.56.10:8080"
echo "Web App: http://192.168.56.10"
echo "Prometheus: http://192.168.56.10:9090"
echo "Grafana: http://192.168.56.10:3000 (admin/admin)"
