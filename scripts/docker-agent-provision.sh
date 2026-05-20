#!/usr/bin/env bash
# Crée l'agent Jenkins dynamic-agent (équivalent create-agent.yml) via Docker CLI.
set -euo pipefail

# URL vue depuis le conteneur agent (réseau Docker jenkins-net)
JENKINS_AGENT_URL="${JENKINS_AGENT_URL:-http://jenkins:8080}"
JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME:-dynamic-agent}"
JENKINS_AGENT_IMAGE="${JENKINS_AGENT_IMAGE:-my-jenkins-agent}"
JENKINS_NETWORK="${JENKINS_NETWORK:-jenkins-net}"
JENKINS_AGENT_SECRET="${JENKINS_AGENT_SECRET:?JENKINS_AGENT_SECRET requis}"
JENKINS_WORKDIR="${JENKINS_WORKDIR:-/home/jenkins}"

echo "==> Provision agent ${JENKINS_AGENT_NAME}"
echo "    Jenkins URL (agent): ${JENKINS_AGENT_URL}"

docker network inspect "${JENKINS_NETWORK}" >/dev/null 2>&1 || docker network create "${JENKINS_NETWORK}"

# S'assurer que Jenkins est sur le même réseau
if docker inspect jenkins >/dev/null 2>&1; then
  docker network connect "${JENKINS_NETWORK}" jenkins 2>/dev/null || true
fi

docker rm -f "${JENKINS_AGENT_NAME}" 2>/dev/null || true

# Commande Java sur UNE seule ligne (sinon les arguments -url/-secret sont ignorés)
docker run -d \
  --name "${JENKINS_AGENT_NAME}" \
  --privileged \
  --user root \
  --network "${JENKINS_NETWORK}" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "${JENKINS_AGENT_IMAGE}" \
  bash -c "curl -fsSL -o /tmp/agent.jar ${JENKINS_AGENT_URL}/jnlpJars/agent.jar && exec java -jar /tmp/agent.jar -url ${JENKINS_AGENT_URL}/ -secret ${JENKINS_AGENT_SECRET} -name ${JENKINS_AGENT_NAME} -webSocket -workDir ${JENKINS_WORKDIR}"

sleep 3
echo "==> Logs agent (dernières lignes) :"
docker logs "${JENKINS_AGENT_NAME}" 2>&1 | tail -15 || true

if ! docker ps --filter "name=${JENKINS_AGENT_NAME}" --filter "status=running" -q | grep -q .; then
  echo "ERROR: le conteneur ${JENKINS_AGENT_NAME} ne tourne pas" >&2
  docker logs "${JENKINS_AGENT_NAME}" 2>&1 || true
  exit 1
fi

echo "==> Conteneur ${JENKINS_AGENT_NAME} démarré"
