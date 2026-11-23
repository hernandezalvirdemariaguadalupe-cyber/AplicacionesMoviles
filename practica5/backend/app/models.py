import json
from datetime import datetime

from app import db


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    # Nullable desde la Práctica 5: las cuentas creadas con Google no tienen contraseña local.
    password_hash = db.Column(db.String(255), nullable=True)
    email = db.Column(db.String(255), unique=True, nullable=True)
    google_sub = db.Column(db.String(255), unique=True, nullable=True)
    display_name = db.Column(db.String(120), nullable=True)
    role = db.Column(db.String(20), nullable=False, default="user")
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    tasks = db.relationship(
        "Task", backref="owner", lazy=True, cascade="all, delete-orphan"
    )

    @property
    def is_admin(self):
        return self.role == "admin"

    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "display_name": self.display_name,
            "role": self.role,
            "auth_provider": "google" if self.google_sub else "local",
            "created_at": self.created_at.isoformat(),
        }


class Task(db.Model):
    __tablename__ = "tasks"

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(120), nullable=False)
    description = db.Column(db.String(500), nullable=True)
    completed = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "completed": self.completed,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "user_id": self.user_id,
        }


class SearchHistory(db.Model):
    """Búsquedas hechas por el usuario en la API pública (Open Library)."""

    __tablename__ = "search_history"
    __table_args__ = (db.UniqueConstraint("user_id", "client_id", name="uq_history_client"),)

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    # UUID generado en el dispositivo: hace idempotente el reenvío desde la cola offline.
    client_id = db.Column(db.String(64), nullable=False)
    query = db.Column(db.String(200), nullable=False)
    results_count = db.Column(db.Integer, nullable=False, default=0)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "client_id": self.client_id,
            "query": self.query,
            "results_count": self.results_count,
            "created_at": self.created_at.isoformat(),
        }


class Favorite(db.Model):
    """Libro marcado como favorito. Se borra de forma lógica (tombstone) para
    poder aplicar last-write-wins con operaciones que llegan tarde desde la cola offline."""

    __tablename__ = "favorites"
    __table_args__ = (db.UniqueConstraint("user_id", "work_key", name="uq_favorite_work"),)

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    work_key = db.Column(db.String(40), nullable=False)  # p. ej. "OL45883W"
    title = db.Column(db.String(300), nullable=False)
    authors_json = db.Column(db.Text, nullable=False, default="[]")
    subjects_json = db.Column(db.Text, nullable=False, default="[]")
    cover_id = db.Column(db.Integer, nullable=True)
    first_publish_year = db.Column(db.Integer, nullable=True)
    deleted = db.Column(db.Boolean, nullable=False, default=False)
    # Momento (reloj del cliente, UTC) de la última modificación aceptada.
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def to_dict(self):
        return {
            "work_key": self.work_key,
            "title": self.title,
            "authors": json.loads(self.authors_json or "[]"),
            "subjects": json.loads(self.subjects_json or "[]"),
            "cover_id": self.cover_id,
            "first_publish_year": self.first_publish_year,
            "deleted": self.deleted,
            "updated_at": self.updated_at.isoformat(),
            "created_at": self.created_at.isoformat(),
        }


class ProcessedOperation(db.Model):
    """Operaciones de la cola offline ya aplicadas. Evita duplicados en reintentos."""

    __tablename__ = "processed_operations"
    __table_args__ = (db.UniqueConstraint("user_id", "op_id", name="uq_processed_op"),)

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    op_id = db.Column(db.String(64), nullable=False)
    status = db.Column(db.String(20), nullable=False)
    processed_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)


class RevokedToken(db.Model):
    """JTI de tokens cerrados con /logout."""

    __tablename__ = "revoked_tokens"

    id = db.Column(db.Integer, primary_key=True)
    jti = db.Column(db.String(64), unique=True, nullable=False, index=True)
    revoked_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
