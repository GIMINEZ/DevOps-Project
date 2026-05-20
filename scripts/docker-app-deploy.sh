#!/usr/bin/env bash
# Déploie task-manager (équivalent deploy.yml) via Docker CLI.
set -euo pipefail

REGISTRY="${REGISTRY:-localhost:5000}"
IMAGE_NAME="${IMAGE_NAME:-task-manager}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
APP_NAME="${APP_NAME:-task-manager-app}"
APP_PORT="${APP_PORT:-8080}"
JENKINS_NETWORK="${JENKINS_NETWORK:-jenkins-net}"

IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "==> Déploiement ${IMAGE} → port ${APP_PORT}"

docker pull "${IMAGE}"
docker rm -f "${APP_NAME}" 2>/dev/null || true

docker run -d \
  --name "${APP_NAME}" \
  --restart unless-stopped \
  --network "${JENKINS_NETWORK}" \
  -p "${APP_PORT}:5000" \
  "${IMAGE}"

for i in $(seq 1 20); do
  if curl -sf "http://127.0.0.1:${APP_PORT}/health" >/dev/null; then
    echo "==> Health OK — http://localhost:${APP_PORT}"
    exit 0
  fi
  echo "  Attente health check (${i}/20)..."
  sleep 3
done

echo "ERROR: health check échoué sur le port ${APP_PORT}" >&2
exit 1
