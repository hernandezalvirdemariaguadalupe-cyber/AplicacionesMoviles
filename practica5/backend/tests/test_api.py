import uuid

import pytest

from app import create_app, db


def fake_google_verifier(raw):
    # Token simulado con el formato "sub|email" para no depender de la red.
    if raw == "bad":
        raise ValueError("firma invalida")
    sub, email = raw.split("|")
    return {"sub": sub, "email": email, "email_verified": True, "name": email.split("@")[0]}


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{tmp_path / 'test.db'}")
    monkeypatch.setenv("ADMIN_USERNAME", "admin")
    monkeypatch.setenv("ADMIN_PASSWORD", "admin-pass-123")
    monkeypatch.setenv("ADMIN_EMAILS", "jefa@example.com")
    app = create_app({"TESTING": True, "GOOGLE_VERIFIER": fake_google_verifier})
    with app.test_client() as c:
        yield c
    with app.app_context():
        db.drop_all()


def login(client, username, password="secreto1", register=True):
    if register:
        client.post("/register", json={"username": username, "password": password})
    r = client.post("/login", json={"username": username, "password": password})
    assert r.status_code == 200, r.get_json()
    return {"Authorization": f"Bearer {r.get_json()['access_token']}"}


def fav_op(key, ts, op="favorite_add", op_id=None):
    return {
        "op_id": op_id or str(uuid.uuid4()),
        "type": op,
        "timestamp": ts,
        "payload": {"work_key": key, "title": "Libro " + key, "authors": ["A"], "subjects": ["Fantasy"]},
    }


def test_crud_tareas_de_practica2_sigue_funcionando(client):
    h = login(client, "ana")
    r = client.post("/tasks", json={"title": "t1"}, headers=h)
    assert r.status_code == 201
    tid = r.get_json()["id"]
    assert client.get("/tasks", headers=h).get_json()[0]["title"] == "t1"
    assert client.put(f"/tasks/{tid}", json={"completed": True}, headers=h).get_json()["completed"]
    assert client.delete(f"/tasks/{tid}", headers=h).status_code == 200


def test_me_y_logout_revoca_token(client):
    h = login(client, "ana")
    assert client.get("/me", headers=h).get_json()["role"] == "user"
    assert client.post("/logout", headers=h).status_code == 200
    assert client.get("/me", headers=h).status_code == 401


def test_google_login_crea_y_reutiliza_cuenta(client):
    r1 = client.post("/auth/google", json={"id_token": "g-1|lupe@example.com"})
    r2 = client.post("/auth/google", json={"id_token": "g-1|lupe@example.com"})
    assert r1.status_code == r2.status_code == 200
    assert r1.get_json()["user"]["id"] == r2.get_json()["user"]["id"]
    assert r1.get_json()["user"]["auth_provider"] == "google"
    assert client.post("/auth/google", json={"id_token": "bad"}).status_code == 401
    # Una cuenta de Google no puede entrar por /login (no tiene contraseña local).
    username = r1.get_json()["user"]["username"]
    assert client.post("/login", json={"username": username, "password": ""}).status_code == 401


def test_google_admin_por_correo(client):
    r = client.post("/auth/google", json={"id_token": "g-2|jefa@example.com"})
    assert r.get_json()["user"]["role"] == "admin"


def test_sync_es_idempotente(client):
    h = login(client, "ana")
    op = fav_op("OL1W", "2026-11-01T10:00:00Z")
    hist = {"op_id": "h1", "type": "history_add", "timestamp": "2026-11-01T10:00:00Z",
            "payload": {"client_id": "c1", "query": "tolkien", "results_count": 5}}
    r1 = client.post("/me/sync", json={"operations": [op, hist]}, headers=h).get_json()
    # Reintento tras un timeout: mismas operaciones.
    r2 = client.post("/me/sync", json={"operations": [op, hist]}, headers=h).get_json()
    assert [x["status"] for x in r1["results"]] == ["applied", "applied"]
    assert [x["status"] for x in r2["results"]] == ["duplicate", "duplicate"]
    assert len(r2["favorites"]) == 1 and len(r2["history"]) == 1


def test_last_write_wins_en_favoritos(client):
    h = login(client, "ana")
    client.post("/me/sync", json={"operations": [fav_op("OL2W", "2026-11-01T12:00:00Z", "favorite_remove")]}, headers=h)
    client.post("/me/sync", json={"operations": [fav_op("OL2W", "2026-11-01T11:00:00Z")]}, headers=h)
    # El "add" es más viejo que el "remove" que no existía -> remove sobre inexistente no crea tombstone,
    # así que el add se aplica. Ahora un remove viejo no debe ganar contra el add.
    r = client.post("/me/sync", json={"operations": [fav_op("OL2W", "2026-11-01T10:00:00Z", "favorite_remove")]}, headers=h).get_json()
    assert r["results"][0]["status"] == "stale"
    assert [f["work_key"] for f in r["favorites"]] == ["OL2W"]
    r = client.post("/me/sync", json={"operations": [fav_op("OL2W", "2026-11-01T13:00:00Z", "favorite_remove")]}, headers=h).get_json()
    assert r["results"][0]["status"] == "applied" and r["favorites"] == []


def test_operacion_invalida_se_rechaza_sin_romper_el_lote(client):
    h = login(client, "ana")
    bad = fav_op("no-es-clave", "2026-11-01T10:00:00Z")
    good = fav_op("OL3W", "2026-11-01T10:00:00Z")
    r = client.post("/me/sync", json={"operations": [bad, good]}, headers=h).get_json()
    assert [x["status"] for x in r["results"]] == ["rejected", "applied"]
    assert client.post("/me/sync", json="no", headers=h).status_code == 400


def test_datos_aislados_por_usuario(client):
    ha = login(client, "ana")
    hb = login(client, "beto")
    client.put("/me/favorites/OL4W", json={"title": "x"}, headers=ha)
    assert client.get("/me/favorites", headers=hb).get_json() == []
    assert len(client.get("/me/favorites", headers=ha).get_json()) == 1


def test_admin_autorizado_y_usuario_denegado(client):
    hu = login(client, "ana")
    client.post("/me/history", json={"query": "dune", "client_id": "x1"}, headers=hu)
    ana_id = client.get("/me", headers=hu).get_json()["id"]

    assert client.get("/admin/users", headers=hu).status_code == 403
    assert client.get(f"/admin/users/{ana_id}/history", headers=hu).status_code == 403

    ha = login(client, "admin", "admin-pass-123", register=False)
    users = client.get("/admin/users", headers=ha).get_json()
    assert any(u["username"] == "ana" and u["history_count"] == 1 for u in users)
    r = client.get(f"/admin/users/{ana_id}/history", headers=ha).get_json()
    assert r["history"][0]["query"] == "dune"
    assert client.get(f"/admin/users/{ana_id}/favorites", headers=ha).status_code == 200
    assert client.get("/admin/users/9999/favorites", headers=ha).status_code == 404


def test_usuario_no_puede_escalar_rol_desde_el_cliente(client):
    hu = login(client, "ana")
    client.post("/register", json={"username": "eva", "password": "secreto1", "role": "admin"})
    he = login(client, "eva", register=False)
    assert client.get("/me", headers=he).get_json()["role"] == "user"
    assert client.patch("/admin/users/1/role", json={"role": "admin"}, headers=hu).status_code == 403
