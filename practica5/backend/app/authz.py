from functools import wraps

from flask import jsonify
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

from app import db
from app.models import User


def current_user():
    return db.session.get(User, int(get_jwt_identity()))


def admin_required(fn):
    """Autorización en el backend: el rol se lee de la BD en cada petición,
    no del claim del token ni de lo que muestre la interfaz."""

    @wraps(fn)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
        user = current_user()
        if user is None or not user.is_admin:
            return jsonify({"error": "Acceso denegado: se requiere rol administrador"}), 403
        return fn(*args, **kwargs)

    return wrapper
