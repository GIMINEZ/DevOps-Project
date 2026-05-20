# Documentation complète — Projet DevOps Task Manager

**Statut : projet terminé et validé** (build Jenkins #15 — `Finished: SUCCESS`)

Ce document décrit l’architecture, le rôle de chaque fichier, le flux CI/CD et les choix techniques du projet **IRT43 / DevOps**.

---

## 1. Objectif du projet

Mettre en place une chaîne **CI/CD** complète autour d’une application **Flask** de gestion de tâches :

| Objectif pédagogique | Réalisation |
|--------------------|-------------|
| Code versionné sur GitHub | Dépôt `GIMINEZ/DevOps-Project` |
| Jenkins master + agent dynamique | Master `jenkins` + agent `dynamic-agent` |
| Provisioning agent via Ansible | Playbooks + scripts Docker via SSH |
| Build, tests, image Docker | Pipeline sur `dynamic-agent` |
| Registry privé | `local-registry` sur port 5000 |
| Déploiement automatique | `task-manager-app` sur port 8080 |
| Suppression agent inactif | `destroy-agent` en `post { always }` |

---

## 2. Architecture globale

```mermaid
flowchart TB
    subgraph dev["Développement"]
        DEV[Code Flask + tests]
        GIT[GitHub DevOps-Project]
    end

    subgraph jenkins_master["Jenkins Master (built-in)"]
        J[Jenkins :8081]
        P1[Provision Agent]
        P4[Deploy App]
        P5[Destroy Agent]
    end

    subgraph host["Machine hôte Docker"]
        ANS[User ansible + SSH]
        SOCK[/var/run/docker.sock]
        REG[(local-registry :5000)]
        APP[task-manager-app :8080]
    end

    subgraph agent["Agent dynamique (éphémère)"]
        DA[dynamic-agent]
        P2[Checkout + Tests]
        P3[Build + Push image]
    end

    DEV --> GIT
    GIT -->|Webhook / Build manuel| J
    J --> P1
    P1 -->|SSH + Docker| ANS
    ANS --> DA
    P1 --> DA
    DA --> P2 --> P3
    P3 --> REG
    J --> P4
    P4 -->|SSH + Docker| APP
    J --> P5
    P5 -->|supprime| DA
```

### Composants infrastructure

| Composant | Conteneur / service | Port | Rôle |
|-----------|---------------------|------|------|
| Jenkins master | `jenkins` | 8081 (hôte) / 8080 (interne) | Orchestration pipeline |
| Registry Docker | `local-registry` | 5000 | Stockage images `task-manager` |
| Agent Jenkins | `dynamic-agent` | — | Exécute build, tests, push |
| Application | `task-manager-app` | 8080 | App Flask en production |
| Réseau Docker | `jenkins-net` | — | Communication Jenkins ↔ agent ↔ app |

---

## 3. Pipeline Jenkins (Jenkinsfile)

Le fichier `Jenkinsfile` définit un pipeline **déclaratif** en 4 grandes phases.

### 3.1 Variables d’environnement

```groovy
IMAGE_NAME = 'task-manager'
IMAGE_TAG  = BUILD_NUMBER          // ex. 15
REGISTRY   = 'localhost:5000'
JENKINS_AGENT_NAME = 'dynamic-agent'
JENKINS_API_URL    = 'http://127.0.0.1:8080'   // API depuis conteneur Jenkins
JENKINS_AGENT_URL  = 'http://jenkins:8080'     // URL vue par l'agent Docker
ANSIBLE_SSH_HOST   = '172.17.0.1'              // Gateway Docker → hôte
ANSIBLE_SSH_USER   = 'ansible'
JENKINS_AGENT_SECRET = '<secret JNLP du nœud Jenkins>'
```

### 3.2 Étapes détaillées

| Stage | Nœud Jenkins | Actions |
|-------|--------------|---------|
| **Provision Agent** | `built-in` (master) | `destroy-agent` → `create-agent` → `wait-for-agent.sh` |
| **CI/CD — Checkout** | `dynamic-agent` | Clone du dépôt GitHub |
| **CI/CD — Install & Test** | `dynamic-agent` | `venv` + `pytest` (5 tests, ~87 % couverture) |
| **CI/CD — Build Docker** | `dynamic-agent` | `docker build` → tag `:BUILD_NUMBER` et `:latest` |
| **CI/CD — Push Registry** | `dynamic-agent` | `docker push` vers `localhost:5000` |
| **Deploy** | `built-in` | Déploiement `task-manager-app` via SSH (user ansible) |
| **Post always** | `built-in` | `destroy-agent` — suppression conteneur agent |

### 3.3 Pourquoi deux nœuds ?

- **built-in** : a accès **SSH** vers l’hôte (`ansible@172.17.0.1`) pour créer/détruire l’agent et déployer l’app.
- **dynamic-agent** : a le **socket Docker** pour builder et pousser les images, mais pas les clés SSH vers l’hôte.

---

## 4. Application Flask (TaskFlow)

### 4.1 Structure du code

```
app/
├── __init__.py      # Factory Flask, config SQLite, init DB
├── models.py        # Modèle Task (SQLAlchemy)
├── routes.py        # Routes web + API REST + /health
└── templates/
    └── index.html   # Interface TaskFlow (gestion tâches)
run.py               # Serveur dev (port 8080 par défaut)
wsgi.py              # Point d'entrée Gunicorn (production)
```

### 4.2 Modèle de données `Task`

| Champ | Type | Description |
|-------|------|-------------|
| `id` | Integer | Clé primaire |
| `title` | String(200) | Titre obligatoire |
| `description` | Text | Description optionnelle |
| `status` | String | `todo`, `in_progress`, `done` |
| `priority` | String | `low`, `medium`, `high` |
| `created_at` / `updated_at` | DateTime | Horodatage UTC |

Base SQLite : `instance/tasks.db` (créée automatiquement).

### 4.3 API REST

| Méthode | URL | Description |
|---------|-----|-------------|
| GET | `/health` | Santé pour Docker / Jenkins |
| GET | `/api/tasks` | Liste (`?status=todo` optionnel) |
| POST | `/api/tasks` | Créer une tâche (JSON) |
| GET | `/api/tasks/<id>` | Détail |
| PUT | `/api/tasks/<id>` | Modifier |
| DELETE | `/api/tasks/<id>` | Supprimer |

### 4.4 Tests (`tests/test_app.py`)

5 tests pytest couvrant : health, CRUD, validation titre vide, statut invalide.

---

## 5. Docker — Application

### 5.1 `Dockerfile` (application)

- Image de base : `python:3.12-slim`
- Utilisateur non-root : `appuser`
- Serveur : **Gunicorn** (2 workers) sur port **5000** (interne conteneur)
- **HEALTHCHECK** : `GET /health`

### 5.2 `jenkins-agent/Dockerfile` (agent Jenkins)

Image de référence `my-jenkins-agent` : JDK 17, Docker CLI, Python, Git, curl — pour exécuter les jobs pipeline.

### 5.3 Images produites par le pipeline

```
localhost:5000/task-manager:15      # tag = numéro de build
localhost:5000/task-manager:latest
```

---

## 6. Ansible

Dossier `ansible/` — automatisation infrastructure (équivalent manuel des scripts Docker).

### 6.1 Fichiers

| Fichier | Rôle |
|---------|------|
| `inventory.ini` | Cible `localhost`, connexion locale, `ansible_become=false` |
| `group_vars/all.yml` | Variables : URLs Jenkins, noms images, ports, secret agent |
| `requirements.yml` | Collection `community.docker` |
| `create-agent.yml` | Crée le conteneur `dynamic-agent` (JNLP WebSocket) |
| `destroy-agent.yml` | Supprime le conteneur agent |
| `deploy.yml` | Pull image + lance `task-manager-app` + health check |

### 6.2 Exécution réelle dans le pipeline

Jenkins **n’a pas** `ansible-playbook` dans son conteneur. L’exécution passe par :

1. **SSH** : Jenkins → `ansible@172.17.0.1`
2. **Scripts Docker** en priorité sur l’hôte (`docker-agent-provision.sh`, etc.)

Les playbooks restent la **référence déclarative** ; les scripts shell garantissent le fonctionnement sans sudo.

---

## 7. Scripts shell (`scripts/`)

| Script | Rôle |
|--------|------|
| **`run-ansible.sh`** | Point d’entrée unique : local → sudo ansible → **SSH** → Docker local. Appelé par Jenkins. |
| **`docker-agent-provision.sh`** | Crée `dynamic-agent` sur `jenkins-net`, commande JNLP en une ligne, affiche logs |
| **`docker-agent-destroy.sh`** | `docker rm -f dynamic-agent` |
| **`docker-app-deploy.sh`** | Pull image, run `task-manager-app`, health via `docker exec` |
| **`wait-for-agent.sh`** | Attend `INFO: Connected` dans les logs Docker (SSH), pas l’API Jenkins |
| **`setup-jenkins-ssh.sh`** | Configure clé SSH Jenkins → user `ansible` (à lancer une fois sur l’hôte) |

### 7.1 Flux `run-ansible.sh`

```
1. ansible-playbook local ?
2. sudo -u ansible ?
3. SSH ansible@172.17.0.1 → scripts Docker ou ansible-playbook
4. Docker local (si socket disponible)
5. Sinon → erreur explicite
```

---

## 8. Projet Ansible sur l’hôte (`~/projet-ansible-jenkins`)

Configuration initiale (user `ansible`) — peut être synchronisée avec `ansible/` du dépôt :

```
create-agent.yml
destroy-agent.yml
inventory.ini
```

Le pipeline utilise désormais les fichiers **du dépôt Git** copiés via SCP lors des appels SSH.

---

## 9. Séquence d’un build réussi (#15)

```
1. [built-in]  destroy-agent          → OK
2. [built-in]  create-agent           → dynamic-agent Connected
3. [built-in]  wait-for-agent         → logs Docker OK (tentative 1/24)
4. [dynamic-agent] checkout + tests   → 5 passed
5. [dynamic-agent] docker build       → image :15
6. [dynamic-agent] docker push        → registry localhost:5000
7. [built-in]  deploy                 → task-manager-app Health OK
8. [built-in]  destroy-agent          → agent supprimé
→ Finished: SUCCESS
```

---

## 10. Accès et vérification

| Service | URL / commande |
|---------|----------------|
| Application déployée | http://localhost:8080 |
| Health check | `curl http://localhost:8080/health` |
| Jenkins | http://localhost:8081 |
| Registry | `localhost:5000` |

```bash
# Conteneurs actifs après build
docker ps | grep -E 'jenkins|task-manager|registry'

# Logs application
docker logs task-manager-app
```

---

## 11. Arborescence complète du dépôt

```
DevOps-Project/
├── app/                          # Application Flask
├── ansible/                      # Playbooks Infrastructure
├── scripts/                      # Automatisation shell (Jenkins)
├── tests/                        # Tests pytest
├── jenkins-agent/                # Dockerfile agent Jenkins
├── Jenkinsfile                   # Pipeline CI/CD
├── Dockerfile                    # Image application
├── requirements.txt              # Dépendances prod
├── requirements-dev.txt          # + pytest
├── run.py / wsgi.py
├── pytest.ini
├── README.md                     # Guide rapide
├── DEVOPS.md                     # Configuration Jenkins / dépannage
└── DOCUMENTATION.md              # Ce document
```

---

## 12. Points techniques importants (leçons apprises)

1. **Port 5000** : occupé par le registry → app en **8080** sur l’hôte.
2. **Jenkins dans Docker** : Ansible via **SSH** vers l’hôte, pas dans le conteneur Jenkins.
3. **Secret JNLP** : doit correspondre au nœud `dynamic-agent` dans Jenkins.
4. **Commande Java agent** : doit être sur **une seule ligne** (sinon agent offline).
5. **`JENKINS_URL` du job** : ne pas utiliser `localhost:8081` pour l’API interne → utiliser `JENKINS_API_URL`.
6. **Health check deploy** : `docker exec` dans le conteneur, pas `curl localhost:8080` depuis l’agent.
7. **Deploy sur built-in** : même logique que Provision (SSH vers hôte).

---

## 13. Améliorations possibles (hors scope actuel)

- Webhook GitHub automatique à chaque push
- Credential Jenkins pour `JENKINS_AGENT_SECRET` (Secret text)
- Ansible pur sans scripts shell (sudo NOPASSWD pour user ansible)
- Déploiement multi-environnements (staging / prod)
- Plugin Jenkins EC2/Kubernetes pour agents éphémères natifs

---

## 14. Conclusion

Le projet est **complet** au regard du cahier des charges :

- Application Flask fonctionnelle avec tests
- Pipeline Jenkins automatisé de bout en bout
- Agent dynamique provisionné et détruit automatiquement
- Image Docker versionnée dans un registry privé
- Application déployée et vérifiée par health check

**Build de référence :** #15 — `Finished: SUCCESS` — Application : http://localhost:8080
