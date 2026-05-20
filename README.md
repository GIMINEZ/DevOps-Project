# Task Manager — Projet DevOps complet

Application Flask de **gestion des tâches** intégrée dans une chaîne **CI/CD** : Jenkins, Ansible, Docker et registry privé.

## Architecture

```
GitHub → Jenkins (built-in)
           ↓ Ansible create-agent
         dynamic-agent → Tests → Build → Push registry
           ↓ Ansible deploy
         task-manager-app (:8080)
           ↓ post always
         Ansible destroy-agent
```

## Documentation

| Document | Contenu |
|----------|---------|
| **[DOCUMENTATION.md](DOCUMENTATION.md)** | Architecture complète, rôles des fichiers, pipeline détaillé |
| **DEVOPS.md** | Configuration Jenkins, Ansible, dépannage |
| Ce README | Application Flask, API, tests locaux |

## Démarrage rapide (local)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python run.py
```

→ http://localhost:8080

## Tests

```bash
pytest tests/ -v
```

## Pipeline Jenkins

Le `Jenkinsfile` exécute automatiquement :

1. **Provision** — `ansible/create-agent.yml`
2. **Tests** — pytest (5 tests)
3. **Build & Push** — image `localhost:5000/task-manager:BUILD_NUMBER`
4. **Deploy** — `ansible/deploy.yml` → http://localhost:8080
5. **Destroy** — `ansible/destroy-agent.yml` (toujours, en `post`)

### Avant le premier build Jenkins

1. Créer la credential ou variable `JENKINS_AGENT_SECRET` (voir **DEVOPS.md**)
2. Vérifier : Jenkins (`8081`), registry (`5000`), réseau `jenkins-net`
3. Pousser le code sur GitHub et lancer le job

## Structure

```
.
├── app/                  # Application Flask
├── ansible/              # Playbooks (create, destroy, deploy)
├── scripts/              # run-ansible.sh, wait-for-agent.sh
├── jenkins-agent/        # Dockerfile image agent
├── tests/
├── Jenkinsfile
├── Dockerfile
├── DEVOPS.md
└── README.md
```

## API

| Méthode | URL |
|---------|-----|
| GET | `/health` |
| GET/POST | `/api/tasks` |
| GET/PUT/DELETE | `/api/tasks/<id>` |

## Variables d'environnement (app)

| Variable | Défaut |
|----------|--------|
| `PORT` | `8080` |
| `SECRET_KEY` | à changer en prod |
| `DATABASE_URL` | SQLite `instance/tasks.db` |
