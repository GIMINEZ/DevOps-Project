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

### 0. User ansible dans le groupe docker

```bash
sudo usermod -aG docker ansible
# se déconnecter/reconnecter ou: newgrp docker
```

Les playbooks n'utilisent plus `sudo` (`become: false`). Docker CLI est utilisé en priorité via SSH.

### 0b. SSH Jenkins → hôte Ansible (obligatoire)

Jenkins tourne **dans un conteneur** sans `ansible-playbook`. Les playbooks s'exécutent sur l'hôte via l'utilisateur `ansible` en SSH.

Sur la machine hôte (une seule fois) :

```bash
cd /home/ahmedsalem/Desktop/IRT43/Projet
sudo bash scripts/setup-jenkins-ssh.sh
```

Vérification :

```bash
docker exec -u jenkins jenkins ssh -o BatchMode=yes ansible@172.17.0.1 "ansible-playbook --version"
```

Si l'IP gateway diffère :

```bash
ip route | awk '/default/{print $3}'   # souvent 172.17.0.1
export SSH_HOST=172.17.0.1
sudo bash scripts/setup-jenkins-ssh.sh
```

### 1. Secret agent JNLP (obligatoire si offline)

1. **Manage Jenkins** → **Nodes** → `dynamic-agent` → **Configure**
2. Cliquer **Show secret** et copier la valeur
3. Dans le job Pipeline → **Environment** → variable :
   - Name: `JENKINS_AGENT_SECRET`
   - Value: *(coller le secret)*

> Si l'agent reste **offline**, le secret du job ne correspond plus à celui du nœud Jenkins.

### 1b. Credential secret (optionnel)

1. **Manage Jenkins** → **Credentials** → **Secret text** id: `jenkins-agent-secret`
2. Ou supprimer `JENKINS_URL=http://localhost:8081/` du job (conflit avec l'API interne)

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

Le stage **Deploy** s'exécute sur le master Jenkins (`built-in`) via SSH vers l'hôte, car l'agent `dynamic-agent` n'a pas les clés SSH.

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
