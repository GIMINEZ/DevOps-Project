from datetime import datetime, timezone

from flask import Blueprint, jsonify, render_template, request

from app import db
from app.models import Task

bp = Blueprint("main", __name__)


@bp.route("/health")
def health():
    return jsonify({"status": "ok", "service": "task-manager"})


@bp.route("/")
def index():
    return render_template("index.html")


@bp.route("/api/tasks", methods=["GET"])
def list_tasks():
    status = request.args.get("status")
    query = Task.query.order_by(Task.created_at.desc())
    if status:
        query = query.filter_by(status=status)
    return jsonify([task.to_dict() for task in query.all()])


@bp.route("/api/tasks/<int:task_id>", methods=["GET"])
def get_task(task_id):
    task = db.session.get(Task, task_id)
    if not task:
        return jsonify({"error": "Tâche introuvable"}), 404
    return jsonify(task.to_dict())


@bp.route("/api/tasks", methods=["POST"])
def create_task():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    if not title:
        return jsonify({"error": "Le titre est obligatoire"}), 400

    status = data.get("status", "todo")
    priority = data.get("priority", "medium")
    if status not in Task.VALID_STATUSES:
        return jsonify({"error": f"Statut invalide. Valeurs: {Task.VALID_STATUSES}"}), 400
    if priority not in Task.VALID_PRIORITIES:
        return jsonify({"error": f"Priorité invalide. Valeurs: {Task.VALID_PRIORITIES}"}), 400

    now = datetime.now(timezone.utc)
    task = Task(
        title=title,
        description=(data.get("description") or "").strip(),
        status=status,
        priority=priority,
        created_at=now,
        updated_at=now,
    )
    db.session.add(task)
    db.session.commit()
    return jsonify(task.to_dict()), 201


@bp.route("/api/tasks/<int:task_id>", methods=["PUT"])
def update_task(task_id):
    task = db.session.get(Task, task_id)
    if not task:
        return jsonify({"error": "Tâche introuvable"}), 404

    data = request.get_json(silent=True) or {}
    if "title" in data:
        title = (data["title"] or "").strip()
        if not title:
            return jsonify({"error": "Le titre ne peut pas être vide"}), 400
        task.title = title
    if "description" in data:
        task.description = (data["description"] or "").strip()
    if "status" in data:
        if data["status"] not in Task.VALID_STATUSES:
            return jsonify({"error": f"Statut invalide. Valeurs: {Task.VALID_STATUSES}"}), 400
        task.status = data["status"]
    if "priority" in data:
        if data["priority"] not in Task.VALID_PRIORITIES:
            return jsonify({"error": f"Priorité invalide. Valeurs: {Task.VALID_PRIORITIES}"}), 400
        task.priority = data["priority"]

    task.updated_at = datetime.now(timezone.utc)
    db.session.commit()
    return jsonify(task.to_dict())


@bp.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    task = db.session.get(Task, task_id)
    if not task:
        return jsonify({"error": "Tâche introuvable"}), 404
    db.session.delete(task)
    db.session.commit()
    return "", 204
