#!/usr/bin/env bash
# Exécute un playbook Ansible (local, user ansible, ou conteneur Docker).
set -euo pipefail

PLAYBOOK="${1:?Usage: run-ansible.sh <playbook.yml> [ansible extra args...]}"
shift || true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANSIBLE_DIR="${ROOT}/ansible"
EXTRA=("$@")

run_playbook() {
  local -a cmd=(
    ansible-playbook
    -i "${ANSIBLE_DIR}/inventory.ini"
    "${ANSIBLE_DIR}/${PLAYBOOK}"
  )
  cmd+=("${EXTRA[@]}")
  "${cmd[@]}"
}

install_collections() {
  if command -v ansible-galaxy &>/dev/null; then
    ansible-galaxy collection install -r "${ANSIBLE_DIR}/requirements.yml" -p "${ANSIBLE_DIR}/collections" --force 2>/dev/null || true
    export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_DIR}/collections:${ANSIBLE_COLLECTIONS_PATH:-}"
  fi
}

# 1) ansible-playbook disponible (user ansible ou CI)
if command -v ansible-playbook &>/dev/null; then
  install_collections
  run_playbook
  exit 0
fi

# 2) Fallback : user ansible sur l'hôte (setup courant du projet)
if id ansible &>/dev/null && sudo -n -u ansible true 2>/dev/null; then
  install_collections
  sudo -n -u ansible env ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_DIR}/collections" \
    ansible-playbook -i "${ANSIBLE_DIR}/inventory.ini" "${ANSIBLE_DIR}/${PLAYBOOK}" "${EXTRA[@]}"
  exit 0
fi

# 3) Conteneur Ansible avec accès Docker (Jenkins master / agent)
if command -v docker &>/dev/null; then
  EXTRA_ARGS=""
  if [ "${#EXTRA[@]}" -gt 0 ]; then
    EXTRA_ARGS="${EXTRA[*]}"
  fi
  docker run --rm \
    --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${ANSIBLE_DIR}:/ansible:ro" \
    -e JENKINS_AGENT_SECRET \
    -e IMAGE_TAG \
    -e REGISTRY \
    -e IMAGE_NAME \
    cytopia/ansible:latest \
    sh -c "
      ansible-galaxy collection install -r /ansible/requirements.yml -p /ansible/collections --force &&
      ANSIBLE_COLLECTIONS_PATH=/ansible/collections \
      ansible-playbook -i /ansible/inventory.ini /ansible/${PLAYBOOK} ${EXTRA_ARGS}
    "
  exit 0
fi

echo "ERROR: ansible-playbook introuvable. Installez Ansible ou montez docker.sock dans Jenkins." >&2
exit 1
