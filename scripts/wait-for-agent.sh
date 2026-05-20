#!/usr/bin/env bash
# Attend que l'agent Jenkins dynamic-agent soit en ligne.
set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://127.0.0.1:8080}"
AGENT_NAME="${JENKINS_AGENT_NAME:-dynamic-agent}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-60}"
SLEEP_SEC="${SLEEP_SEC:-5}"

echo "Attente de l'agent Jenkins '${AGENT_NAME}' sur ${JENKINS_URL} ..."

for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  RESPONSE="$(curl -sf "${JENKINS_URL}/computer/${AGENT_NAME}/api/json" 2>/dev/null || true)"

  if echo "${RESPONSE}" | grep -q '"offline":false'; then
    echo "Agent '${AGENT_NAME}' en ligne (${i}/${MAX_ATTEMPTS})."
    exit 0
  fi

  echo "  Tentative ${i}/${MAX_ATTEMPTS} — agent pas encore prêt..."
  sleep "${SLEEP_SEC}"
done

echo "ERROR: l'agent '${AGENT_NAME}' ne s'est pas connecté à temps." >&2
exit 1
