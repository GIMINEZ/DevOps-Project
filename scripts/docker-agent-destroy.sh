#!/usr/bin/env bash
# Supprime l'agent Jenkins dynamic-agent (équivalent destroy-agent.yml).
set -euo pipefail

JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME:-dynamic-agent}"

echo "==> Suppression agent ${JENKINS_AGENT_NAME}"
docker rm -f "${JENKINS_AGENT_NAME}" 2>/dev/null || true
echo "==> Agent supprimé"
