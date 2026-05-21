"""Tâches du projet DevOps Task Manager — chargées au premier démarrage."""
from datetime import datetime, timezone

from app import db
from app.models import Task

PROJECT_TASKS = [
    # --- Application Flask ---
    {
        "category": "Application Flask",
        "title": "Architecture Flask (factory pattern)",
        "description": "Structure app/ avec create_app(), blueprints et configuration SQLite.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Application Flask",
        "title": "Modèle Task + base de données",
        "description": "SQLAlchemy : titre, description, statut, priorité, horodatage.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Application Flask",
        "title": "API REST CRUD /api/tasks",
        "description": "Endpoints GET, POST, PUT, DELETE avec validation JSON.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Application Flask",
        "title": "Endpoint santé /health",
        "description": "Contrôle pour Docker HEALTHCHECK, Jenkins et load balancer.",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Application Flask",
        "title": "Interface web TaskFlow",
        "description": "UI claire : formulaire, liste, filtres, statistiques, toasts.",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Application Flask",
        "title": "Division des tâches par catégorie",
        "description": "Affichage groupé des livrables du projet DevOps dans l'interface.",
        "status": "done",
        "priority": "medium",
    },
    # --- Tests & Qualité ---
    {
        "category": "Tests & Qualité",
        "title": "Suite pytest (5 tests)",
        "description": "Tests health, CRUD, validations titre et statut.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Tests & Qualité",
        "title": "Couverture de code (~87%)",
        "description": "pytest-cov intégré au stage Install & Test du pipeline.",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Tests & Qualité",
        "title": "requirements-dev.txt",
        "description": "pytest, pytest-cov pour l'environnement CI.",
        "status": "done",
        "priority": "low",
    },
    # --- Docker & Registry ---
    {
        "category": "Docker & Registry",
        "title": "Dockerfile application",
        "description": "Image Python 3.12, Gunicorn, utilisateur appuser, HEALTHCHECK.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Docker & Registry",
        "title": "Image agent Jenkins (my-jenkins-agent)",
        "description": "Dockerfile jenkins-agent/ : JDK, Docker CLI, Python, Git.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Docker & Registry",
        "title": "Registry privé local-registry",
        "description": "Registry Docker sur port 5000 pour task-manager:BUILD_NUMBER.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Docker & Registry",
        "title": "Réseau Docker jenkins-net",
        "description": "Communication Jenkins ↔ dynamic-agent ↔ task-manager-app.",
        "status": "done",
        "priority": "medium",
    },
    # --- Jenkins & CI/CD ---
    {
        "category": "Jenkins & CI/CD",
        "title": "Jenkins master (conteneur jenkins)",
        "description": "Orchestration pipeline, interface :8081, exécuteur built-in.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Jenkins & CI/CD",
        "title": "Jenkinsfile pipeline complet",
        "description": "Provision → CI/CD → Deploy → post destroy (agent none).",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Jenkins & CI/CD",
        "title": "Intégration GitHub",
        "description": "Pipeline SCM : GIMINEZ/DevOps-Project.git, branche main.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Jenkins & CI/CD",
        "title": "Stage Install & Test",
        "description": "venv, pip install, pytest -v --cov sur dynamic-agent.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Jenkins & CI/CD",
        "title": "Stage Build Docker Image",
        "description": "docker build + tag :latest sur l'agent dynamique.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Jenkins & CI/CD",
        "title": "Stage Push to Registry",
        "description": "docker push localhost:5000/task-manager:BUILD_NUMBER.",
        "status": "done",
        "priority": "high",
    },
    # --- Ansible & Provisioning ---
    {
        "category": "Ansible & Provisioning",
        "title": "Playbook create-agent.yml",
        "description": "Création conteneur dynamic-agent, JNLP WebSocket, socket Docker.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Ansible & Provisioning",
        "title": "Playbook destroy-agent.yml",
        "description": "Suppression automatique de l'agent en fin de pipeline.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Ansible & Provisioning",
        "title": "Playbook deploy.yml",
        "description": "Déploiement task-manager-app avec health check.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Ansible & Provisioning",
        "title": "Scripts Docker (provision / destroy / deploy)",
        "description": "Fallback sans sudo : docker-agent-provision.sh, docker-app-deploy.sh.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Ansible & Provisioning",
        "title": "run-ansible.sh + SSH Jenkins→hôte",
        "description": "Exécution via ansible@172.17.0.1 depuis conteneur Jenkins.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Ansible & Provisioning",
        "title": "wait-for-agent.sh",
        "description": "Attente connexion agent via logs Docker (INFO: Connected).",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Ansible & Provisioning",
        "title": "User ansible + inventory.ini",
        "description": "Ansible local, become:false, collection community.docker.",
        "status": "done",
        "priority": "medium",
    },
    # --- Déploiement ---
    {
        "category": "Déploiement",
        "title": "Provision agent à la demande",
        "description": "Agent créé au début de chaque build, détruit en post always.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Déploiement",
        "title": "Déploiement task-manager-app",
        "description": "Conteneur sur port 8080, restart unless-stopped, réseau jenkins-net.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Déploiement",
        "title": "Health check déploiement",
        "description": "Vérification /health via docker exec dans le conteneur app.",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Déploiement",
        "title": "Pipeline SUCCESS (build #15)",
        "description": "Chaîne complète validée : provision → CI → deploy → destroy.",
        "status": "done",
        "priority": "high",
    },
    # --- Documentation ---
    {
        "category": "Documentation",
        "title": "README.md",
        "description": "Guide démarrage, API, structure projet.",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Documentation",
        "title": "DEVOPS.md",
        "description": "Config Jenkins, SSH, secret JNLP, dépannage.",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Documentation",
        "title": "DOCUMENTATION.md",
        "description": "Architecture détaillée, rôles fichiers, séquence build.",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Documentation",
        "title": "Dépôt GitHub public",
        "description": "Code versionné : github.com/GIMINEZ/DevOps-Project.",
        "status": "done",
        "priority": "medium",
    },
    # --- Configuration ---
    {
        "category": "Configuration",
        "title": "Secret JNLP agent dynamic-agent",
        "description": "Variable JENKINS_AGENT_SECRET alignée avec le nœud Jenkins.",
        "status": "done",
        "priority": "high",
    },
    {
        "category": "Configuration",
        "title": "setup-jenkins-ssh.sh",
        "description": "Clé SSH conteneur Jenkins → user ansible sur l'hôte.",
        "status": "done",
        "priority": "medium",
    },
    {
        "category": "Configuration",
        "title": "Port 8080 application / 5000 registry",
        "description": "Éviter conflit registry Docker (5000) vs app Flask (8080).",
        "status": "done",
        "priority": "low",
    },
]

def _ensure_category_column():
    from sqlalchemy import inspect, text

    inspector = inspect(db.engine)
    if not inspector.has_table("tasks"):
        return
    columns = {col["name"] for col in inspector.get_columns("tasks")}
    if "category" not in columns:
        with db.engine.begin() as conn:
            conn.execute(
                text("ALTER TABLE tasks ADD COLUMN category VARCHAR(80) DEFAULT 'Général' NOT NULL")
            )


def seed_project_tasks(force: bool = False) -> int:
    """Insère les tâches du projet si absentes ou sur demande (force)."""
    _ensure_category_column()

    project_categories = {t["category"] for t in PROJECT_TASKS}

    if not force and Task.query.filter(Task.category.in_(project_categories)).count() > 0:
        return 0

    if force:
        Task.query.filter(Task.category.in_(project_categories)).delete()
        db.session.commit()

    now = datetime.now(timezone.utc)
    for item in PROJECT_TASKS:
        task = Task(
            title=item["title"],
            description=item["description"],
            status=item["status"],
            priority=item["priority"],
            category=item["category"],
            created_at=now,
            updated_at=now,
        )
        db.session.add(task)

    db.session.commit()
    return len(PROJECT_TASKS)


def get_categories():
    return sorted({t["category"] for t in PROJECT_TASKS})
