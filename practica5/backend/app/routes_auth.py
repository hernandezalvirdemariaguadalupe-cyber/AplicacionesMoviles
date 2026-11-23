import re

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import create_access_token, get_jwt, jwt_required

from app import bcrypt, db
from app.authz import current_user
from app.models import RevokedToken, User

auth_bp = Blueprint("auth", __name__)


def _issue_token(user):
    # El rol viaja en el token sólo como dato informativo para la UI;
    # el backend siempre vuelve a leerlo de la base de datos (ver authz.admin_required).
    token = create_access_token(identity=str(user.id), additional_claims={"role": user.role})
    return jsonify({"access_token": token, "user": user.to_dict()}), 200


@auth_bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    if not username or not password:
        return jsonify({"error": "username y password son obligatorios"}), 400

    if len(password) < 6:
        return jsonify({"error": "La contrasena debe tener al menos 6 caracteres"}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({"error": "El usuario ya existe"}), 400

    password_hash = bcrypt.generate_password_hash(password).decode("utf-8")
    user = User(username=username, password_hash=password_hash)
    db.session.add(user)
    db.session.commit()

    return jsonify({"message": "Usuario registrado correctamente", "user": user.to_dict()}), 201


@auth_bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    user = User.query.filter_by(username=username).first()

    if (
        not user
        or not user.password_hash
        or not bcrypt.check_password_hash(user.password_hash, password)
    ):
        return jsonify({"error": "Usuario o contrasena incorrectos"}), 401

    return _issue_token(user)


def _verify_google_id_token(raw_token):
    """Valida firma, emisor, expiración y audiencia del ID token con las llaves públicas de Google.
    Se aísla en una función para poder sustituirla en las pruebas."""
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token

    audiences = current_app.config["GOOGLE_CLIENT_IDS"]
    if not audiences:
        raise ValueError("El servidor no tiene configurado GOOGLE_CLIENT_IDS")
    info = id_token.verify_oauth2_token(raw_token, google_requests.Request(), audience=None)
    if info.get("aud") not in audiences:
        raise ValueError("El token no fue emitido para esta aplicacion")
    if info.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise ValueError("Emisor invalido")
    return info


def _unique_username(base):
    base = re.sub(r"[^a-zA-Z0-9_.-]", "", base)[:60] or "usuario"
    candidate, n = base, 1
    while User.query.filter_by(username=candidate).first():
        n += 1
        candidate = f"{base}{n}"
    return candidate


@auth_bp.post("/auth/google")
def google_login():
    data = request.get_json(silent=True) or {}
    raw_token = data.get("id_token") or ""
    if not raw_token:
        return jsonify({"error": "id_token es obligatorio"}), 400

    try:
        info = current_app.config.get("GOOGLE_VERIFIER", _verify_google_id_token)(raw_token)
    except ValueError as exc:
        return jsonify({"error": f"Token de Google invalido: {exc}"}), 401

    if not info.get("email_verified", False):
        return jsonify({"error": "El correo de Google no esta verificado"}), 401

    sub = info["sub"]
    email = (info.get("email") or "").lower()

    user = User.query.filter_by(google_sub=sub).first()
    if user is None and email:
        # Vincula una cuenta existente con el mismo correo (p. ej. creada antes con Google en otro dispositivo).
        user = User.query.filter_by(email=email).first()
    if user is None:
        user = User(username=_unique_username(email.split("@")[0] if email else "google"))
        db.session.add(user)

    user.google_sub = sub
    user.email = email or user.email
    user.display_name = info.get("name") or user.display_name
    if email and email in current_app.config["ADMIN_EMAILS"]:
        user.role = "admin"
    db.session.commit()

    return _issue_token(user)


@auth_bp.get("/me")
@jwt_required()
def me():
    user = current_user()
    if user is None:
        return jsonify({"error": "Usuario no encontrado"}), 404
    return jsonify(user.to_dict()), 200


@auth_bp.post("/logout")
@jwt_required()
def logout():
    jti = get_jwt()["jti"]
    if not RevokedToken.query.filter_by(jti=jti).first():
        db.session.add(RevokedToken(jti=jti))
        db.session.commit()
    return jsonify({"message": "Sesion cerrada"}), 200
