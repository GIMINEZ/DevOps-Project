#!/usr/bin/env bash
# Crée l'agent Jenkins dynamic-agent (équivalent create-agent.yml) via Docker CLI.
set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://jenkins:8080}"
JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME:-dynamic-agent}"
JENKINS_AGENT_IMAGE="${JENKINS_AGENT_IMAGE:-my-jenkins-agent}"
JENKINS_NETWORK="${JENKINS_NETWORK:-jenkins-net}"
JENKINS_AGENT_SECRET="${JENKINS_AGENT_SECRET:?JENKINS_AGENT_SECRET requis}"
JENKINS_WORKDIR="${JENKINS_WORKDIR:-/home/jenkins}"

echo "==> Provision agent ${JENKINS_AGENT_NAME}"

docker network inspect "${JENKINS_NETWORK}" >/dev/null 2>&1 || docker network create "${JENKINS_NETWORK}"
docker rm -f "${JENKINS_AGENT_NAME}" 2>/dev/null || true

docker run -d \
  --name "${JENKINS_AGENT_NAME}" \
  --privileged \
  --user root \
  --network "${JENKINS_NETWORK}" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "${JENKINS_AGENT_IMAGE}" \
  bash -c "
    curl -fsSL -o agent.jar ${JENKINS_URL}/jnlpJars/agent.jar &&
    java -jar agent.jar
      -url ${JENKINS_URL}/
      -secret ${JENKINS_AGENT_SECRET}
      -name ${JENKINS_AGENT_NAME}
      -webSocket
      -workDir ${JENKINS_WORKDIR}
  "

echo "==> Conteneur ${JENKINS_AGENT_NAME} démarré"
