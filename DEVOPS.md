# Guide DevOps — Jenkins + Ansible + Docker

Architecture automatisée du projet **Task Manager**.

## Schéma du pipeline

```
GitHub (push)
    ↓
Jenkins (built-in) ──► Ansible create-agent.yml ──► dynamic-agent
    ↓
dynamic-agent : Checkout → Tests → Build → Push registry
    ↓
Ansible deploy.yml ──► task-manager-app (port 8080)
    ↓
Jenkins post always ──► Ansible destroy-agent.yml
```

## Prérequis infra

| Composant | Nom / port | Rôle |
|-----------|------------|------|
| Jenkins | `jenkins` — http://localhost:8081 | Master |
| Registry | `local-registry` — localhost:5000 | Images Docker |
| Réseau Docker | `jenkins-net` | Jenkins + agent + app |
| Agent image | `my-jenkins-agent` | Build pipeline |
| User Ansible | `ansible` (optionnel) | Playbooks sur l'hôte |

## Configuration Jenkins (une fois)

### 1. Credential secret agent

1. **Manage Jenkins** → **Credentials** → **System** → **Global**
2. **Add Credentials** → Kind: **Secret text**
3. ID : `jenkins-agent-secret`
4. Secret : copier depuis **Manage Jenkins** → **Nodes** → `dynamic-agent` → **Show secret**

### 2. Job Pipeline

- Type : **Pipeline**
- Definition : **Pipeline script from SCM**
- Repository : `https://github.com/GIMINEZ/DevOps-Project.git`
- Script Path : `Jenkinsfile`
- Label agent (dans Jenkinsfile) : `dynamic-agent`

### 3. Webhook GitHub (recommandé)

GitHub → Settings → Webhooks → URL :

`http://VOTRE_IP:8081/github-webhook/`

## Commandes manuelles (debug)

```bash
# Construire l'image agent (si besoin)
docker build -t my-jenkins-agent ./jenkins-agent

# Provisionner l'agent
./scripts/run-ansible.sh create-agent.yml \
  -e "jenkins_agent_secret=VOTRE_SECRET"

# Attendre l'agent
JENKINS_URL=http://localhost:8081 ./scripts/wait-for-agent.sh

# Déployer manuellement
./scripts/run-ansible.sh deploy.yml -e "image_tag=latest"

# Supprimer l'agent
./scripts/run-ansible.sh destroy-agent.yml
```

## Playbooks Ansible

| Fichier | Action |
|---------|--------|
| `ansible/create-agent.yml` | Crée le conteneur `dynamic-agent` (JNLP) |
| `ansible/destroy-agent.yml` | Supprime l'agent |
| `ansible/deploy.yml` | Lance `task-manager-app` sur le port 8080 |

Variables : `ansible/group_vars/all.yml` (surcharge via `-e` ou env).

## Vérification après build

```bash
docker ps | grep -E 'dynamic-agent|task-manager'
curl http://localhost:8080/health
```

Réponse attendue : `{"status":"ok","service":"task-manager"}`

## Dépannage

| Problème | Solution |
|----------|----------|
| Agent ne se connecte pas | Vérifier `jenkins_agent_secret` et réseau `jenkins-net` |
| `ansible-playbook` introuvable | Le script utilise Docker (`cytopia/ansible`) ou user `ansible` |
| Port 5000 occupé | Registry Docker — l'app utilise le port **8080** |
| built-in indisponible | Activer l'exécuteur sur le master Jenkins |

## Synchroniser avec ~/projet-ansible-jenkins

Copier les playbooks du repo vers l'ancien dossier si vous utilisez l'user `ansible` :

```bash
cp -r ansible/* ~/projet-ansible-jenkins/
```
