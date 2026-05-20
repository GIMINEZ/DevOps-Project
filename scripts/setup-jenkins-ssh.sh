#!/usr/bin/env bash
# Configure la clé SSH du conteneur Jenkins vers l'utilisateur ansible sur l'hôte.
# À lancer UNE FOIS sur la machine hôte (pas dans Jenkins).
set -euo pipefail

JENKINS_CONTAINER="${JENKINS_CONTAINER:-jenkins}"
ANSIBLE_USER="${ANSIBLE_USER:-ansible}"
SSH_HOST="${SSH_HOST:-172.17.0.1}"

echo "Configuration SSH Jenkins → ${ANSIBLE_USER}@${SSH_HOST}"

if ! docker ps --format '{{.Names}}' | grep -q "^${JENKINS_CONTAINER}$"; then
  echo "Conteneur '${JENKINS_CONTAINER}' introuvable. Ajustez JENKINS_CONTAINER." >&2
  exit 1
fi

docker exec -u jenkins "${JENKINS_CONTAINER}" bash -c '
  [ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
  chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519
  cat ~/.ssh/id_ed25519.pub
' > /tmp/jenkins_id_ed25519.pub

PUBKEY="$(cat /tmp/jenkins_id_ed25519.pub)"
mkdir -p "/home/${ANSIBLE_USER}/.ssh"
grep -qF "${PUBKEY}" "/home/${ANSIBLE_USER}/.ssh/authorized_keys" 2>/dev/null || \
  echo "${PUBKEY}" >> "/home/${ANSIBLE_USER}/.ssh/authorized_keys"
chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "/home/${ANSIBLE_USER}/.ssh"
chmod 700 "/home/${ANSIBLE_USER}/.ssh"
chmod 600 "/home/${ANSIBLE_USER}/.ssh/authorized_keys"

docker exec -u jenkins "${JENKINS_CONTAINER}" \
  ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
  "${ANSIBLE_USER}@${SSH_HOST}" "echo SSH OK depuis Jenkins"

echo "Terminé. Relancez le pipeline Jenkins."
