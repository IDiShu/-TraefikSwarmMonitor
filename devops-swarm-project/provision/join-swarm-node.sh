#!/bin/bash
set -e

MANAGER_IP=$1
TOKEN_FILE="/vagrant/worker-token.txt"

# Ждём появления файла токена (макс. 60 секунд)
for i in {1..12}; do
  if [ -f "$TOKEN_FILE" ]; then
    break
  fi
  echo "[INFO] Waiting for token file... attempt $i/12"
  sleep 5
done

if [ ! -f "$TOKEN_FILE" ]; then
  echo "Error: token file $TOKEN_FILE not found after waiting. Manager may not be ready."
  exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")

echo "[INFO] Joining the Swarm cluster..."
docker swarm join --token "$TOKEN" "$MANAGER_IP:2377"
