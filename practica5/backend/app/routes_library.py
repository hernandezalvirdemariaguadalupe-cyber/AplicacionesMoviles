"""Historial de búsquedas, favoritos y sincronización de la cola offline (Práctica 5)."""

import json
import re
import uuid
from datetime import datetime, timezone

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy.exc import IntegrityError

from app import db
from app.models import Favorite, ProcessedOperation, SearchHistory

library_bp = Blueprint("library", __name__, url_prefix="/me")

WORK_KEY_RE = re.compile(r"^OL\d+W$")
MAX_OPS_PER_SYNC = 200


class OpError(ValueError):
    pass


def _uid():
    return int(get_jwt_identity())


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _parse_ts(value):
    """ISO-8601 -> datetime UTC sin zona. Un reloj adelantado del cliente se recorta a la hora
    del servidor para que no pueda 'ganar' para siempre en last-write-wins."""
    if not value:
        return _now()
    try:
        ts = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError as exc:
        raise OpError("timestamp invalido") from exc
    if ts.tzinfo is not None:
        ts = ts.astimezone(timezone.utc).replace(tzinfo=None)
    return min(ts, _now())


def _normalize_work_key(raw):
    key = str(raw or "").strip().rsplit("/", 1)[-1]
    if not WORK_KEY_RE.match(key):
        raise OpError("work_key invalido (se espera algo como OL45883W)")
    return key


def _str_list(value, limit):
    if not isinstance(value, list):
        return []
    return [str(v)[:120] for v in value if isinstance(v, (str, int))][:limit]


def _opt_int(value):
    try:
        return int(value) if value is not None else None
    except (TypeError, ValueError):
        return None


# ---------- operaciones de dominio (compartidas por REST y /sync) ----------

def apply_favorite_add(user_id, payload, ts):
    key = _normalize_work_key(payload.get("work_key"))
    title = str(payload.get("title") or "").strip()[:300]
    if not title:
        raise OpError("title es obligatorio")
    fav = Favorite.query.filter_by(user_id=user_id, work_key=key).first()
    if fav is not None and fav.updated_at > ts:
        return "stale", fav
    if fav is None:
        fav = Favorite(user_id=user_id, work_key=key, created_at=ts)
        db.session.add(fav)
    fav.title = title
    fav.authors_json = json.dumps(_str_list(payload.get("authors"), 10), ensure_ascii=False)
    fav.subjects_json = json.dumps(_str_list(payload.get("subjects"), 25), ensure_ascii=False)
    fav.cover_id = _opt_int(payload.get("cover_id"))
    fav.first_publish_year = _opt_int(payload.get("first_publish_year"))
    fav.deleted = False
    fav.updated_at = ts
    return "applied", fav


def apply_favorite_remove(user_id, payload, ts):
    key = _normalize_work_key(payload.get("work_key"))
    fav = Favorite.query.filter_by(user_id=user_id, work_key=key).first()
    if fav is None:
        return "applied", None  # quitar algo que no existe es idempotente
    if fav.updated_at > ts:
        return "stale", fav
    fav.deleted = True
    fav.updated_at = ts
    return "applied", fav


def apply_history_add(user_id, payload, ts):
    query = str(payload.get("query") or "").strip()[:200]
    if not query:
        raise OpError("query es obligatorio")
    client_id = str(payload.get("client_id") or uuid.uuid4())[:64]
    existing = SearchHistory.query.filter_by(user_id=user_id, client_id=client_id).first()
    if existing:
        return "duplicate", existing
    entry = SearchHistory(
        user_id=user_id,
        client_id=client_id,
        query=query,
        results_count=max(0, _opt_int(payload.get("results_count")) or 0),
        created_at=ts,
    )
    db.session.add(entry)
    return "applied", entry


def apply_history_clear(user_id, payload, ts):
    SearchHistory.query.filter(
        SearchHistory.user_id == user_id, SearchHistory.created_at <= ts
    ).delete(synchronize_session=False)
    return "applied", None


HANDLERS = {
    "favorite_add": apply_favorite_add,
    "favorite_remove": apply_favorite_remove,
    "history_add": apply_history_add,
    "history_clear": apply_history_clear,
}


def _favorites(user_id, include_deleted=False):
    q = Favorite.query.filter_by(user_id=user_id)
    if not include_deleted:
        q = q.filter_by(deleted=False)
    return [f.to_dict() for f in q.order_by(Favorite.updated_at.desc()).all()]


def _history(user_id, limit=100):
    rows = (
        SearchHistory.query.filter_by(user_id=user_id)
        .order_by(SearchHistory.created_at.desc())
        .limit(limit)
        .all()
    )
    return [h.to_dict() for h in rows]


def _limit_arg(default=100, maximum=500):
    try:
        return max(1, min(int(request.args.get("limit", default)), maximum))
    except ValueError:
        return default


# ---------- REST ----------

@library_bp.get("/favorites")
@jwt_required()
def list_favorites():
    include_deleted = request.args.get("include_deleted") == "1"
    return jsonify(_favorites(_uid(), include_deleted)), 200


@library_bp.put("/favorites/<work_key>")
@jwt_required()
def put_favorite(work_key):
    data = request.get_json(silent=True) or {}
    data["work_key"] = work_key
    try:
        status, fav = apply_favorite_add(_uid(), data, _parse_ts(data.get("timestamp")))
    except OpError as exc:
        return jsonify({"error": str(exc)}), 400
    db.session.commit()
    return jsonify({"status": status, "favorite": fav.to_dict()}), 200


@library_bp.delete("/favorites/<work_key>")
@jwt_required()
def delete_favorite(work_key):
    try:
        status, _ = apply_favorite_remove(
            _uid(), {"work_key": work_key}, _parse_ts(request.args.get("timestamp"))
        )
    except OpError as exc:
        return jsonify({"error": str(exc)}), 400
    db.session.commit()
    return jsonify({"status": status}), 200


@library_bp.get("/history")
@jwt_required()
def list_history():
    return jsonify(_history(_uid(), _limit_arg())), 200


@library_bp.post("/history")
@jwt_required()
def add_history():
    data = request.get_json(silent=True) or {}
    try:
        status, entry = apply_history_add(_uid(), data, _parse_ts(data.get("timestamp")))
    except OpError as exc:
        return jsonify({"error": str(exc)}), 400
    db.session.commit()
    return jsonify({"status": status, "entry": entry.to_dict()}), 201 if status == "applied" else 200


@library_bp.delete("/history")
@jwt_required()
def clear_history():
    apply_history_clear(_uid(), {}, _now())
    db.session.commit()
    return jsonify({"status": "applied"}), 200


@library_bp.post("/sync")
@jwt_required()
def sync():
    """Recibe la cola de operaciones pendientes del dispositivo (en orden) y devuelve
    el estado autoritativo del servidor. Cada op_id se aplica como máximo una vez."""
    user_id = _uid()
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "Se esperaba un objeto JSON"}), 400
    ops = data.get("operations") or []
    if not isinstance(ops, list):
        return jsonify({"error": "operations debe ser una lista"}), 400
    if len(ops) > MAX_OPS_PER_SYNC:
        return jsonify({"error": f"Maximo {MAX_OPS_PER_SYNC} operaciones por sincronizacion"}), 413

    results = []
    for op in ops:
        if not isinstance(op, dict):
            results.append({"op_id": None, "status": "rejected", "error": "operacion invalida"})
            continue
        op_id = str(op.get("op_id") or "")[:64]
        if not op_id:
            results.append({"op_id": None, "status": "rejected", "error": "op_id es obligatorio"})
            continue
        if ProcessedOperation.query.filter_by(user_id=user_id, op_id=op_id).first():
            results.append({"op_id": op_id, "status": "duplicate"})
            continue
        handler = HANDLERS.get(op.get("type"))
        try:
            if handler is None:
                raise OpError(f"tipo de operacion desconocido: {op.get('type')}")
            payload = op.get("payload") if isinstance(op.get("payload"), dict) else {}
            status, _ = handler(user_id, payload, _parse_ts(op.get("timestamp")))
            db.session.add(ProcessedOperation(user_id=user_id, op_id=op_id, status=status))
            db.session.commit()
            results.append({"op_id": op_id, "status": status})
        except OpError as exc:
            db.session.rollback()
            # Se registra como procesada para que el cliente la saque de la cola y no la reintente.
            db.session.add(ProcessedOperation(user_id=user_id, op_id=op_id, status="rejected"))
            db.session.commit()
            results.append({"op_id": op_id, "status": "rejected", "error": str(exc)})
        except IntegrityError:
            # Dos peticiones concurrentes con el mismo op_id: la otra ya lo aplicó.
            db.session.rollback()
            results.append({"op_id": op_id, "status": "duplicate"})

    return jsonify(
        {
            "results": results,
            "favorites": _favorites(user_id),
            "history": _history(user_id),
            "server_time": _now().isoformat() + "Z",
        }
    ), 200
