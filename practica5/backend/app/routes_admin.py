from flask import Blueprint, jsonify, request

from app import db
from app.authz import admin_required
from app.models import Favorite, SearchHistory, User

admin_bp = Blueprint("admin", __name__, url_prefix="/admin")


@admin_bp.get("/users")
@admin_required
def list_users():
    users = User.query.order_by(User.id).all()
    out = []
    for u in users:
        d = u.to_dict()
        d["favorites_count"] = Favorite.query.filter_by(user_id=u.id, deleted=False).count()
        d["history_count"] = SearchHistory.query.filter_by(user_id=u.id).count()
        out.append(d)
    return jsonify(out), 200


def _get_user_or_404(user_id):
    user = db.session.get(User, user_id)
    if user is None:
        return None, (jsonify({"error": "Usuario no encontrado"}), 404)
    return user, None


@admin_bp.get("/users/<int:user_id>/history")
@admin_required
def user_history(user_id):
    user, err = _get_user_or_404(user_id)
    if err:
        return err
    rows = (
        SearchHistory.query.filter_by(user_id=user.id)
        .order_by(SearchHistory.created_at.desc())
        .limit(500)
        .all()
    )
    return jsonify({"user": user.to_dict(), "history": [h.to_dict() for h in rows]}), 200


@admin_bp.get("/users/<int:user_id>/favorites")
@admin_required
def user_favorites(user_id):
    user, err = _get_user_or_404(user_id)
    if err:
        return err
    rows = (
        Favorite.query.filter_by(user_id=user.id, deleted=False)
        .order_by(Favorite.updated_at.desc())
        .all()
    )
    return jsonify({"user": user.to_dict(), "favorites": [f.to_dict() for f in rows]}), 200


@admin_bp.patch("/users/<int:user_id>/role")
@admin_required
def set_role(user_id):
    user, err = _get_user_or_404(user_id)
    if err:
        return err
    role = (request.get_json(silent=True) or {}).get("role")
    if role not in ("user", "admin"):
        return jsonify({"error": "role debe ser 'user' o 'admin'"}), 400
    user.role = role
    db.session.commit()
    return jsonify(user.to_dict()), 200
