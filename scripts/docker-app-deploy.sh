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

echo "==> Déploiement ${IMAGE} → port hôte ${APP_PORT}"

docker pull "${IMAGE}"
docker rm -f "${APP_NAME}" 2>/dev/null || true

docker network inspect "${JENKINS_NETWORK}" >/dev/null 2>&1 || docker network create "${JENKINS_NETWORK}"

docker run -d \
  --name "${APP_NAME}" \
  --restart unless-stopped \
  --network "${JENKINS_NETWORK}" \
  -p "${APP_PORT}:5000" \
  "${IMAGE}"

echo "==> Attente démarrage Gunicorn..."
sleep 5

# Health check dans le conteneur (fiable depuis n'importe quel exécuteur Docker)
for i in $(seq 1 20); do
  if docker exec "${APP_NAME}" python -c \
    "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health')" 2>/dev/null; then
    echo "==> Health OK (docker exec)"
    # Vérification optionnelle via IP hôte (depuis la machine Docker)
    HOST_IP="$(ip route 2>/dev/null | awk '/default/ {print $3; exit}' || echo '127.0.0.1')"
    if curl -sf "http://127.0.0.1:${APP_PORT}/health" >/dev/null 2>&1; then
      echo "==> Application accessible : http://localhost:${APP_PORT}"
    elif curl -sf "http://${HOST_IP}:${APP_PORT}/health" >/dev/null 2>&1; then
      echo "==> Application accessible : http://${HOST_IP}:${APP_PORT}"
    else
      echo "==> Conteneur OK — essayez http://localhost:${APP_PORT}"
    fi
    exit 0
  fi
  echo "  Attente health check (${i}/20)..."
  sleep 3
done

echo "ERROR: health check échoué" >&2
docker logs "${APP_NAME}" 2>&1 | tail -20 >&2 || true
exit 1
