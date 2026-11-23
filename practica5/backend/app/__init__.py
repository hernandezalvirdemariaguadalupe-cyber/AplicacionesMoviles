import os
from datetime import timedelta

from flask import Flask, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager
from werkzeug.exceptions import HTTPException
from werkzeug.middleware.proxy_fix import ProxyFix

db = SQLAlchemy()
bcrypt = Bcrypt()
jwt = JWTManager()


def _database_uri(instance_dir):
    url = os.environ.get("DATABASE_URL", "").strip()
    if not url:
        return f"sqlite:///{os.path.join(instance_dir, 'app.db')}"
    # Render entrega "postgres://" o "postgresql://": se fija explícitamente el driver psycopg 3
    # (el que está en requirements.txt) para no depender del driver por defecto de SQLAlchemy.
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            url = "postgresql+psycopg://" + url[len(prefix):]
            break
    return url


def create_app(test_config=None):
    app = Flask(__name__)
    # Detrás del proxy HTTPS de Render: respeta X-Forwarded-Proto/Host.
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)

    basedir = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
    instance_dir = os.path.join(basedir, "instance")
    os.makedirs(instance_dir, exist_ok=True)

    app.config["SQLALCHEMY_DATABASE_URI"] = _database_uri(instance_dir)
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {"pool_pre_ping": True}
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["JWT_SECRET_KEY"] = os.environ.get(
        "JWT_SECRET_KEY", "dev-secret-key-cambiar-en-produccion"
    )
    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(
        minutes=int(os.environ.get("JWT_EXPIRES_MINUTES", "1440"))
    )
    # IDs de cliente OAuth aceptados como "aud" del ID token de Google (separados por coma).
    app.config["GOOGLE_CLIENT_IDS"] = [
        c.strip() for c in os.environ.get("GOOGLE_CLIENT_IDS", "").split(",") if c.strip()
    ]
    # Correos de Google que reciben rol admin al iniciar sesión (separados por coma).
    app.config["ADMIN_EMAILS"] = [
        e.strip().lower() for e in os.environ.get("ADMIN_EMAILS", "").split(",") if e.strip()
    ]
    if test_config:
        app.config.update(test_config)

    db.init_app(app)
    bcrypt.init_app(app)
    jwt.init_app(app)

    from app.models import RevokedToken  # noqa: F401
    from app import models  # noqa: F401

    with app.app_context():
        # Con varios procesos (gunicorn) otro worker pudo crear tablas/admin primero:
        # se toleran esas carreras en lugar de abortar el arranque.
        try:
            db.create_all()
        except Exception:  # noqa: BLE001
            db.session.rollback()
            app.logger.warning("create_all fallo (probablemente otro worker ya creo las tablas)")
        try:
            _seed_admin(app)
        except Exception:  # noqa: BLE001
            db.session.rollback()
            app.logger.warning("No se pudo sembrar el admin (probablemente ya existe)")

    from app.routes_auth import auth_bp
    from app.routes_tasks import tasks_bp
    from app.routes_library import library_bp
    from app.routes_admin import admin_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(tasks_bp)
    app.register_blueprint(library_bp)
    app.register_blueprint(admin_bp)

    @app.get("/")
    def health_check():
        return {"status": "ok", "service": "AppMoviles Practica 5 API", "version": "5.0"}, 200

    @jwt.token_in_blocklist_loader
    def is_token_revoked(jwt_header, jwt_payload):
        return RevokedToken.query.filter_by(jti=jwt_payload["jti"]).first() is not None

    @jwt.revoked_token_loader
    def revoked_token_callback(jwt_header, jwt_payload):
        return {"error": "La sesion fue cerrada, inicia sesion de nuevo"}, 401

    @jwt.expired_token_loader
    def expired_token_callback(jwt_header, jwt_payload):
        return {"error": "El token ha expirado, inicia sesion de nuevo"}, 401

    @jwt.invalid_token_loader
    def invalid_token_callback(reason):
        return {"error": "Token invalido"}, 401

    @jwt.unauthorized_loader
    def missing_token_callback(reason):
        return {"error": "Falta el token de autorizacion"}, 401

    @app.errorhandler(HTTPException)
    def http_error(err):
        return jsonify({"error": err.description or err.name}), err.code

    return app


def _seed_admin(app):
    """Crea/actualiza una cuenta admin local a partir de variables de entorno.
    Así el rol nunca depende de algo que el cliente pueda enviar."""
    from app.models import User

    username = os.environ.get("ADMIN_USERNAME", "").strip()
    password = os.environ.get("ADMIN_PASSWORD", "")
    if not username or len(password) < 8:
        return
    user = User.query.filter_by(username=username).first()
    if user is None:
        user = User(username=username, role="admin")
        db.session.add(user)
    user.role = "admin"
    user.password_hash = bcrypt.generate_password_hash(password).decode("utf-8")
    db.session.commit()
