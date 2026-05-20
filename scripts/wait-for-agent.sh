#!/usr/bin/env bash
# Attend que l'agent Jenkins dynamic-agent soit en ligne.
set -euo pipefail

# JENKINS_API_URL : API depuis le conteneur Jenkins (ne pas utiliser JENKINS_URL du job → 8081)
JENKINS_API_URL="${JENKINS_API_URL:-http://127.0.0.1:8080}"
JENKINS_API_URL="${JENKINS_API_URL%/}"

AGENT_NAME="${JENKINS_AGENT_NAME:-dynamic-agent}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-36}"
SLEEP_SEC="${SLEEP_SEC:-5}"

echo "Attente de l'agent '${AGENT_NAME}' via API ${JENKINS_API_URL} ..."

for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  RESPONSE="$(curl -sf "${JENKINS_API_URL}/computer/${AGENT_NAME}/api/json" 2>/dev/null || true)"

  if echo "${RESPONSE}" | grep -q '"offline":false'; then
    echo "Agent '${AGENT_NAME}' en ligne (${i}/${MAX_ATTEMPTS})."
    exit 0
  fi

  # Afficher l'état toutes les 6 tentatives
  if [ $((i % 6)) -eq 0 ]; then
    OFFLINE="$(echo "${RESPONSE}" | grep -o '"offline":[^,]*' || echo 'pas de réponse API')"
    echo "  Tentative ${i}/${MAX_ATTEMPTS} — ${OFFLINE}"
    echo "  Vérifiez le secret JNLP dans Jenkins → Nodes → ${AGENT_NAME}"
  else
    echo "  Tentative ${i}/${MAX_ATTEMPTS}..."
  fi
  sleep "${SLEEP_SEC}"
done

echo "ERROR: agent '${AGENT_NAME}' toujours offline." >&2
echo "  1. Jenkins → Manage Nodes → ${AGENT_NAME} → copier le Secret" >&2
echo "  2. Mettre à jour JENKINS_AGENT_SECRET dans le job Jenkins" >&2
echo "  3. docker logs ${AGENT_NAME}" >&2
exit 1
