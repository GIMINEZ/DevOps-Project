#!/usr/bin/env bash
# Exécute Ansible ou fallback Docker/SSH (Jenkins dans conteneur sans ansible).
set -euo pipefail

PLAYBOOK="${1:?Usage: run-ansible.sh <playbook.yml> [ansible extra args...]}"
shift || true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANSIBLE_DIR="${ROOT}/ansible"
SCRIPTS_DIR="${ROOT}/scripts"
EXTRA=("$@")

# --- helpers ---
detect_ssh_host() {
  if [ -n "${ANSIBLE_SSH_HOST:-}" ]; then
    echo "${ANSIBLE_SSH_HOST}"
    return
  fi
  ip route 2>/dev/null | awk '/default/ {print $3; exit}' || true
}

run_playbook_local() {
  install_collections
  ansible-playbook -i "${ANSIBLE_DIR}/inventory.ini" "${ANSIBLE_DIR}/${PLAYBOOK}" "${EXTRA[@]}"
}

install_collections() {
  if command -v ansible-galaxy &>/dev/null; then
    ansible-galaxy collection install -r "${ANSIBLE_DIR}/requirements.yml" \
      -p "${ANSIBLE_DIR}/collections" --force 2>/dev/null || true
    export ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_DIR}/collections:${ANSIBLE_COLLECTIONS_PATH:-}"
  fi
}

run_via_ssh() {
  local host user remote_dir ssh_opts
  host="$(detect_ssh_host)"
  user="${ANSIBLE_SSH_USER:-ansible}"

  if [ -z "${host}" ]; then
    return 1
  fi

  ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"

  if ! ssh ${ssh_opts} "${user}@${host}" "true" 2>/dev/null; then
    echo "SSH non disponible vers ${user}@${host}" >&2
    return 1
  fi

  remote_dir="/tmp/ansible-jenkins-${BUILD_NUMBER:-$$}"
  echo "==> Ansible via SSH ${user}@${host}"

  ssh ${ssh_opts} "${user}@${host}" "mkdir -p '${remote_dir}'"
  scp ${ssh_opts} -r "${ANSIBLE_DIR}/." "${user}@${host}:${remote_dir}/"
  scp ${ssh_opts} "${SCRIPTS_DIR}/docker-agent-provision.sh" \
      "${SCRIPTS_DIR}/docker-agent-destroy.sh" \
      "${SCRIPTS_DIR}/docker-app-deploy.sh" \
      "${user}@${host}:${remote_dir}/" 2>/dev/null || true

  local extra_quoted=""
  if [ "${#EXTRA[@]}" -gt 0 ]; then
    extra_quoted="${EXTRA[*]}"
  fi

  ssh ${ssh_opts} "${user}@${host}" \
    JENKINS_AGENT_SECRET="${JENKINS_AGENT_SECRET:-}" \
    IMAGE_TAG="${IMAGE_TAG:-}" \
    REGISTRY="${REGISTRY:-}" \
    IMAGE_NAME="${IMAGE_NAME:-}" \
    JENKINS_AGENT_URL="${JENKINS_AGENT_URL:-http://jenkins:8080}" \
    JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME:-dynamic-agent}" \
    bash -s <<REMOTE
set -euo pipefail
REMOTE_DIR="${remote_dir}"
PLAYBOOK="${PLAYBOOK}"
EXTRA_ARGS="${extra_quoted}"

# Docker CLI en priorité (user ansible sans sudo)
if command -v docker >/dev/null 2>&1; then
  case "\${PLAYBOOK}" in
    create-agent.yml)
      chmod +x "\${REMOTE_DIR}/docker-agent-provision.sh"
      bash "\${REMOTE_DIR}/docker-agent-provision.sh"
      exit 0
      ;;
    destroy-agent.yml)
      chmod +x "\${REMOTE_DIR}/docker-agent-destroy.sh"
      bash "\${REMOTE_DIR}/docker-agent-destroy.sh"
      exit 0
      ;;
    deploy.yml)
      chmod +x "\${REMOTE_DIR}/docker-app-deploy.sh"
      bash "\${REMOTE_DIR}/docker-app-deploy.sh"
      exit 0
      ;;
  esac
fi

if command -v ansible-playbook >/dev/null 2>&1; then
  ansible-galaxy collection install -r "\${REMOTE_DIR}/requirements.yml" \
    -p "\${REMOTE_DIR}/collections" --force 2>/dev/null || true
  ANSIBLE_COLLECTIONS_PATH="\${REMOTE_DIR}/collections" \
  ansible-playbook -i "\${REMOTE_DIR}/inventory.ini" "\${REMOTE_DIR}/\${PLAYBOOK}" \${EXTRA_ARGS} \
    --extra-vars "ansible_become=false"
  exit 0
fi

echo "Ni ansible-playbook ni docker sur l'hôte distant" >&2
exit 1
REMOTE

  ssh ${ssh_opts} "${user}@${host}" "rm -rf '${remote_dir}'" 2>/dev/null || true
}

run_docker_playbook_local() {
  if ! command -v docker &>/dev/null; then
    return 1
  fi
  if [ ! -S /var/run/docker.sock ]; then
    return 1
  fi

  case "${PLAYBOOK}" in
    create-agent.yml)
      export JENKINS_AGENT_SECRET="${JENKINS_AGENT_SECRET:-}"
      bash "${SCRIPTS_DIR}/docker-agent-provision.sh"
      ;;
    destroy-agent.yml)
      bash "${SCRIPTS_DIR}/docker-agent-destroy.sh"
      ;;
    deploy.yml)
      bash "${SCRIPTS_DIR}/docker-app-deploy.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

run_ansible_docker_image() {
  if ! command -v docker &>/dev/null || [ ! -S /var/run/docker.sock ]; then
    return 1
  fi

  local extra_args=""
  [ "${#EXTRA[@]}" -gt 0 ] && extra_args="${EXTRA[*]}"

  docker run --rm \
    --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${ANSIBLE_DIR}:/ansible:ro" \
    -e JENKINS_AGENT_SECRET \
    -e IMAGE_TAG -e REGISTRY -e IMAGE_NAME \
    cytopia/ansible:latest \
    sh -c "
      ansible-galaxy collection install -r /ansible/requirements.yml -p /ansible/collections --force &&
      ANSIBLE_COLLECTIONS_PATH=/ansible/collections \
      ansible-playbook -i /ansible/inventory.ini /ansible/${PLAYBOOK} ${extra_args}
    "
}

# --- ordre d'exécution ---
if command -v ansible-playbook &>/dev/null; then
  run_playbook_local
  exit 0
fi

if id ansible &>/dev/null && sudo -n -u ansible true 2>/dev/null; then
  install_collections
  sudo -n -u ansible env \
    JENKINS_AGENT_SECRET="${JENKINS_AGENT_SECRET:-}" \
    IMAGE_TAG="${IMAGE_TAG:-}" REGISTRY="${REGISTRY:-}" IMAGE_NAME="${IMAGE_NAME:-}" \
    ANSIBLE_COLLECTIONS_PATH="${ANSIBLE_DIR}/collections" \
    ansible-playbook -i "${ANSIBLE_DIR}/inventory.ini" "${ANSIBLE_DIR}/${PLAYBOOK}" "${EXTRA[@]}"
  exit 0
fi

if run_via_ssh; then
  exit 0
fi

if run_docker_playbook_local; then
  exit 0
fi

# Pas de fallback cytopia pour les playbooks gérés par scripts Docker
case "${PLAYBOOK}" in
  create-agent.yml|destroy-agent.yml|deploy.yml)
    echo "ERROR: échec de ${PLAYBOOK} (SSH et Docker local)." >&2
    exit 1
    ;;
esac

if run_ansible_docker_image; then
  exit 0
fi

echo "ERROR: impossible d'exécuter ${PLAYBOOK}." >&2
echo "  → Configurez SSH: ssh-copy-id ansible@\$(ip route|awk '/default/{print \$3}')" >&2
echo "  → Ou montez /var/run/docker.sock dans le conteneur Jenkins" >&2
exit 1
