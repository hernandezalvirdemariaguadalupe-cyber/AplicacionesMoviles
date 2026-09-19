import os
from datetime import timedelta

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager

db = SQLAlchemy()
bcrypt = Bcrypt()
jwt = JWTManager()


def create_app():
    app = Flask(__name__)

    basedir = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
    instance_dir = os.path.join(basedir, "instance")
    os.makedirs(instance_dir, exist_ok=True)

    app.config["SQLALCHEMY_DATABASE_URI"] = (
        f"sqlite:///{os.path.join(instance_dir, 'app.db')}"
    )
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["JWT_SECRET_KEY"] = os.environ.get(
        "JWT_SECRET_KEY", "dev-secret-key-cambiar-en-produccion"
    )
    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(
        minutes=int(os.environ.get("JWT_EXPIRES_MINUTES", "60"))
    )

    db.init_app(app)
    bcrypt.init_app(app)
    jwt.init_app(app)

    from app.models import User, Task  # noqa: F401

    with app.app_context():
        db.create_all()

    from app.routes_auth import auth_bp
    from app.routes_tasks import tasks_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(tasks_bp)

    @app.get("/")
    def health_check():
        return {"status": "ok", "service": "AppMoviles Practica 2 API"}, 200

    @jwt.expired_token_loader
    def expired_token_callback(jwt_header, jwt_payload):
        return {"error": "El token ha expirado, inicia sesion de nuevo"}, 401

    @jwt.invalid_token_loader
    def invalid_token_callback(reason):
        return {"error": "Token invalido"}, 401

    @jwt.unauthorized_loader
    def missing_token_callback(reason):
        return {"error": "Falta el token de autorizacion"}, 401

    return app
