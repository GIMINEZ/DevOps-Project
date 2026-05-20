# Task Manager — Application Flask DevOps

Application de **gestion des tâches** (CRUD) prête à être poussée sur GitHub et intégrée dans un pipeline CI/CD.

## Architecture cible

```
Code Flask → GitHub → Jenkins → Ansible (agent Docker) → Build → Tests → Image Docker → Registry → Déploiement → Suppression agent
```

## Fonctionnalités

- Interface web pour créer, lister, terminer et supprimer des tâches
- API REST JSON (`/api/tasks`)
- Endpoint santé `/health` (Docker, load balancer)
- Base SQLite (fichier dans `instance/`)
- Tests automatisés (pytest)
- Image Docker avec Gunicorn

## Démarrage local

```bash
cd /home/ahmedsalem/Desktop/IRT43/Projet
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

# Lancer l'application
python run.py
```

Ouvrir : http://localhost:8080

> Le port **5000** est souvent utilisé par le **Docker Registry** (`local-registry`). L’app démarre par défaut sur le port **8080**. Pour forcer un autre port : `PORT=5050 python run.py`

## Tests

```bash
pytest tests/ -v
```

## Docker

```bash
docker build -t task-manager .
docker run -p 5000:5000 task-manager
```

## API

| Méthode | URL | Description |
|---------|-----|-------------|
| GET | `/health` | Santé du service |
| GET | `/api/tasks` | Liste des tâches (`?status=todo`) |
| POST | `/api/tasks` | Créer une tâche |
| GET | `/api/tasks/<id>` | Détail |
| PUT | `/api/tasks/<id>` | Modifier |
| DELETE | `/api/tasks/<id>` | Supprimer |

Exemple :

```bash
curl -X POST http://localhost:5000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Push image Docker","priority":"high"}'
```

## Initialiser le dépôt Git

```bash
git init
git add .
git commit -m "Initial commit: Flask task manager for DevOps pipeline"
git remote add origin https://github.com/VOTRE_USER/task-manager.git
git push -u origin main
```

## Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `PORT` | `8080` | Port d'écoute (évite le conflit avec le registry Docker sur 5000) |
| `SECRET_KEY` | `dev-secret-...` | Clé Flask (à changer en prod) |
| `DATABASE_URL` | SQLite `instance/tasks.db` | URI base de données |
| `FLASK_DEBUG` | `0` | `1` pour le mode debug |

## Structure du projet

```
.
├── app/
│   ├── __init__.py      # Factory Flask
│   ├── models.py        # Modèle Task
│   ├── routes.py        # Routes web + API
│   └── templates/
├── tests/
├── Dockerfile
├── Jenkinsfile
├── requirements.txt
├── run.py
└── wsgi.py
```
