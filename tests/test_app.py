import pytest

from app import create_app, db
from app.models import Task


@pytest.fixture
def client():
    app = create_app({"TESTING": True, "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:"})
    with app.app_context():
        db.create_all()
    with app.test_client() as client:
        yield client
    with app.app_context():
        db.drop_all()


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["service"] == "task-manager"


def test_create_and_list_tasks(client):
    response = client.post(
        "/api/tasks",
        json={"title": "Configurer Jenkins", "description": "Pipeline CI", "priority": "high"},
    )
    assert response.status_code == 201
    task = response.get_json()
    assert task["title"] == "Configurer Jenkins"
    assert task["status"] == "todo"
    assert task["priority"] == "high"

    response = client.get("/api/tasks")
    assert response.status_code == 200
    tasks = response.get_json()
    assert len(tasks) == 1


def test_create_task_without_title_fails(client):
    response = client.post("/api/tasks", json={"title": "  "})
    assert response.status_code == 400


def test_get_update_delete_task(client):
    create = client.post("/api/tasks", json={"title": "Build Docker image"})
    task_id = create.get_json()["id"]

    response = client.get(f"/api/tasks/{task_id}")
    assert response.status_code == 200

    response = client.put(f"/api/tasks/{task_id}", json={"status": "done"})
    assert response.status_code == 200
    assert response.get_json()["status"] == "done"

    response = client.delete(f"/api/tasks/{task_id}")
    assert response.status_code == 204

    response = client.get(f"/api/tasks/{task_id}")
    assert response.status_code == 404


def test_invalid_status(client):
    response = client.post("/api/tasks", json={"title": "Test", "status": "invalid"})
    assert response.status_code == 400
