#!/usr/bin/env bash
# Attend que l'agent Jenkins dynamic-agent soit en ligne.
set -euo pipefail

JENKINS_API_URL="${JENKINS_API_URL:-http://127.0.0.1:8080}"
JENKINS_API_URL="${JENKINS_API_URL%/}"
AGENT_NAME="${JENKINS_AGENT_NAME:-dynamic-agent}"
ANSIBLE_SSH_HOST="${ANSIBLE_SSH_HOST:-}"
ANSIBLE_SSH_USER="${ANSIBLE_SSH_USER:-ansible}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-24}"
SLEEP_SEC="${SLEEP_SEC:-5}"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"

detect_ssh_host() {
  if [ -n "${ANSIBLE_SSH_HOST}" ]; then
    echo "${ANSIBLE_SSH_HOST}"
    return
  fi
  ip route 2>/dev/null | awk '/default/ {print $3; exit}' || true
}

# Méthode 1 : logs Docker sur l'hôte (fiable — l'agent affiche "Connected")
wait_via_docker_logs() {
  local host user
  host="$(detect_ssh_host)"
  user="${ANSIBLE_SSH_USER}"

  if [ -z "${host}" ]; then
    return 1
  fi
  if ! ssh ${SSH_OPTS} "${user}@${host}" "true" 2>/dev/null; then
    return 1
  fi

  echo "Vérification via logs Docker (SSH ${user}@${host})..."

  for i in $(seq 1 "${MAX_ATTEMPTS}"); do
    LOGS="$(ssh ${SSH_OPTS} "${user}@${host}" \
      "docker logs ${AGENT_NAME} 2>&1 | tail -40" 2>/dev/null || true)"

    if echo "${LOGS}" | grep -qE "INFO: Connected|Connection established|handshake completed"; then
      if ssh ${SSH_OPTS} "${user}@${host}" \
        "docker ps --filter name=${AGENT_NAME} --filter status=running -q" | grep -q .; then
        echo "Agent '${AGENT_NAME}' connecté (logs Docker, tentative ${i}/${MAX_ATTEMPTS})."
        return 0
      fi
    fi

    if echo "${LOGS}" | grep -qiE "secret.*invalid|authentication failed|403 Forbidden"; then
      echo "ERROR: secret JNLP invalide — mettez à jour JENKINS_AGENT_SECRET dans le job." >&2
      echo "${LOGS}" | tail -8 >&2
      return 1
    fi

    echo "  Tentative ${i}/${MAX_ATTEMPTS} — en attente de connexion..."
    sleep "${SLEEP_SEC}"
  done
  return 1
}

# Méthode 2 : API Jenkins (nécessite parfois un token)
wait_via_api() {
  local auth_args=()
  if [ -n "${JENKINS_API_USER:-}" ] && [ -n "${JENKINS_API_TOKEN:-}" ]; then
    auth_args=(-u "${JENKINS_API_USER}:${JENKINS_API_TOKEN}")
  fi

  echo "Vérification via API ${JENKINS_API_URL} ..."

  for i in $(seq 1 "${MAX_ATTEMPTS}"); do
    RESPONSE="$(curl -sf "${auth_args[@]}" \
      "${JENKINS_API_URL}/computer/${AGENT_NAME}/api/json" 2>/dev/null || true)"

    if echo "${RESPONSE}" | grep -q '"offline":false'; then
      echo "Agent '${AGENT_NAME}' en ligne via API (${i}/${MAX_ATTEMPTS})."
      return 0
    fi

    sleep "${SLEEP_SEC}"
  done
  return 1
}

# Ordre : Docker logs (SSH) puis API
if wait_via_docker_logs; then
  exit 0
fi

if wait_via_api; then
  exit 0
fi

echo "ERROR: agent '${AGENT_NAME}' non détecté." >&2
echo "  L'agent peut être connecté — vérifiez : docker logs ${AGENT_NAME}" >&2
echo "  API Jenkins : définir JENKINS_API_USER + JENKINS_API_TOKEN si besoin" >&2
exit 1
