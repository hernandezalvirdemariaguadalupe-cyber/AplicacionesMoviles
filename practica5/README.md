# Práctica 5: Consulta de bases de datos vía APIs y funcionalidades específicas en aplicaciones multiplataforma (Android e iOS)

> 🇪🇸 Español abajo · 🇬🇧 [English version](#english-version)

## Portada

- **Nombre completo:** María Guadalupe Hernández Alvirde
- **Número de boleta:** 2022630105
- **Grupo:** 5CV4
- **Unidad de aprendizaje:** Desarrollo de aplicaciones móviles nativas
- **Profesor:** Gabriel Hurtado Avilés
- **Continuación de:** [Práctica 2, commit `dcdab0e`](https://github.com/hernandezalvirdemariaguadalupe-cyber/AplicacionesMoviles/tree/dcdab0e/practica2)

---

## Resumen

**Biblioteca ESCOM** es una sola aplicación **Flutter** que corre en **Android (7.0+, API 24)** e **iOS (15+)**:

- Conserva el **CRUD de tareas** y el **login con JWT** de la Práctica 2 (mismo backend Flask, ampliado).
- Consulta la API pública **Open Library**: búsqueda por texto, detalle, historial y favoritos.
- Inicio de sesión con **Google**. El ID token se **valida en el backend**.
- Rol **administrador**, verificado en el servidor.
- **Modo sin conexión:** SQLite local, cola de operaciones pendientes y sincronización idempotente con reintentos.
- **Recomendaciones** con una regla reproducible, guardadas para verlas sin red.

```
practica5/
├── backend/   API REST Flask (base: Práctica 2) + Docker Compose + pytest
├── app/       Cliente Flutter único para Android e iOS
│   ├── lib/                  código compartido (100 % Dart)
│   ├── android/  ios/        configuración nativa propia de cada plataforma
│   ├── test/                 pruebas unitarias
│   └── integration_test/     prueba funcional E2E (misma en Android e iOS)
└── docs/      informe técnico y matriz de pruebas
```

## Requisitos

| Herramienta | Uso |
|---|---|
| Flutter 3.50+ (Dart 3.14+) | compilar la app |
| Android Studio + SDK 35+ y un emulador | ejecutar en Android |
| Docker Desktop **o** Python 3.12 | ejecutar el backend localmente |
| macOS + Xcode 16+ | compilar iOS localmente (**opcional**: se usa GitHub Actions, ver abajo) |

## 1. Backend

### Local con Docker Compose
```bash
cd practica5/backend
cp .env.example .env          # edita los valores; .env NO se versiona
docker compose up --build     # http://localhost:5000
docker compose --profile tunnel up   # además, un túnel HTTPS temporal *.trycloudflare.com
```

### Local con Python
```bash
cd practica5/backend
python -m venv .venv && .venv\Scripts\activate      # Windows
pip install -r requirements-dev.txt
python -m pytest          # pruebas
python run.py             # http://localhost:5000
```

### Producción (HTTPS) en Render
El archivo [`render.yaml`](../render.yaml) crea el servicio web (Docker) y un Postgres gratuito.
En Render ve a **New → Blueprint**, elige este repositorio y captura en el panel:
`GOOGLE_CLIENT_IDS`, `ADMIN_EMAILS`, `ADMIN_USERNAME` y `ADMIN_PASSWORD`.
`JWT_SECRET_KEY` se genera solo. Render entrega una URL `https://…onrender.com`.

| Variable | Descripción |
|---|---|
| `JWT_SECRET_KEY` | llave para firmar los JWT |
| `DATABASE_URL` | vacío = SQLite; en Render, Postgres |
| `GOOGLE_CLIENT_IDS` | client IDs de OAuth aceptados como audiencia (Web, iOS), separados por coma |
| `ADMIN_EMAILS` | correos de Google que reciben rol admin |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | cuenta admin local que se crea al arrancar |

### Endpoints

| Método y ruta | Origen | Descripción |
|---|---|---|
| `POST /register`, `POST /login` | Reutilizado (P2) | registro y login con usuario y contraseña. Ahora el JWT incluye el claim `role` |
| `GET/POST /tasks`, `GET/PUT/DELETE /tasks/<id>` | **Reutilizado (P2) sin cambios** | CRUD de tareas |
| `GET /` | Reutilizado | estado del servicio |
| `POST /auth/google` | **Nuevo** | recibe el `id_token` de Google, valida firma, emisor, audiencia y correo verificado, y emite el JWT propio |
| `GET /me` | **Nuevo** | usuario actual y rol (se usa para restaurar la sesión) |
| `POST /logout` | **Nuevo** | revoca el JWT (lista de JTI revocados) |
| `GET /me/favorites`, `PUT/DELETE /me/favorites/<work_key>` | **Nuevo** | favoritos del usuario |
| `GET/POST/DELETE /me/history` | **Nuevo** | historial de búsquedas |
| `POST /me/sync` | **Nuevo** | aplica la cola offline y devuelve el estado del servidor |
| `GET /admin/users`, `GET /admin/users/<id>/history`, `GET /admin/users/<id>/favorites`, `PATCH /admin/users/<id>/role` | **Nuevo** | sólo administradores. Si no, responde **403** |

## 2. App Flutter

### Configuración (sin secretos en el repo)
```bash
cd practica5/app
cp config/example.json config/dev.json   # config/*.json está en .gitignore
```
`config/dev.json`:
```json
{
  "API_BASE_URL": "https://practica5-api.onrender.com",
  "GOOGLE_SERVER_CLIENT_ID": "<client ID Web>.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "<client ID iOS>.apps.googleusercontent.com"
}
```
La app rechaza una `API_BASE_URL` que no sea HTTPS. La única excepción es `http://10.0.2.2:5000` en compilaciones **debug** (emulador contra backend local).

### Android
```bash
flutter run --dart-define-from-file=config/dev.json            # emulador o teléfono
flutter build apk --release --dart-define-from-file=config/dev.json
```

### iOS
- **Sin Mac (método usado):** el workflow [`.github/workflows/practica5.yml`](../.github/workflows/practica5.yml) corre en `macos-latest`:
  1. Compila la app para el simulador.
  2. Arranca un **simulador de iPhone**.
  3. Ejecuta la **misma prueba E2E** que en Android.
  4. Publica capturas, video y la versión del simulador como artefactos (*evidencias-ios*).
- **Con Mac:**
  ```bash
  cp ios/Flutter/GoogleOAuth.xcconfig.example ios/Flutter/GoogleOAuth.xcconfig
  flutter run -d "iPhone 16" --dart-define-from-file=config/dev.json
  ```

### Google Sign-In (configuración OAuth por plataforma)
En Google Cloud Console → *APIs y servicios* → *Credenciales*, crea tres IDs de cliente OAuth:

1. **Aplicación web.** Es el `GOOGLE_SERVER_CLIENT_ID` de la app y va en `GOOGLE_CLIENT_IDS` del backend. Así el ID token se emite con nuestro backend como audiencia.
2. **Android.** Paquete `mx.ipn.escom.biblioteca_app` + SHA-1 de la llave de firma. Para obtener el SHA-1:
   ```bash
   keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
   ```
   No se necesita `google-services.json`.
3. **iOS.** Bundle ID `mx.ipn.escom.bibliotecaApp`. Su ID va en `GOOGLE_IOS_CLIENT_ID` (app) y en `GOOGLE_CLIENT_IDS` (backend). El esquema de URL invertido va en `ios/Flutter/GoogleOAuth.xcconfig`.

### Pruebas
```bash
flutter analyze && flutter test                 # unitarias: recomendaciones, parseo, cola/sync
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart \
  --dart-define-from-file=config/dev.json -d emulator-5554    # E2E con capturas
```

## 3. Sincronización y estrategia de conflictos

1. **Local primero.** Al marcar o desmarcar un favorito, buscar o borrar el historial, la app escribe primero en SQLite y responde al instante, con o sin red. En la misma transacción encola una operación con un **`op_id` (UUID)** en `pending_ops`.
2. **Compactación.** En la cola sólo queda la **última** intención por libro: si marcas, desmarcas y vuelves a marcar sin red, se envía una sola operación.
3. **Envío idempotente.** `POST /me/sync` recibe las operaciones en orden. El servidor guarda cada `op_id` en `processed_operations`, así que **un reintento nunca duplica**. Si la respuesta se pierde (timeout o caída de red), la app reenvía los mismos `op_id` y el servidor contesta `duplicate`. Las operaciones sólo salen de la cola cuando el servidor confirma, por lo que **no se pierden**.
4. **Conflictos en favoritos: last-write-wins** por marca de tiempo de la operación (UTC del dispositivo, recortada a la hora del servidor para que un reloj adelantado no gane siempre). Los borrados se guardan como *tombstones*, así un "quitar" viejo que llega tarde no borra un "agregar" más reciente hecho en otro dispositivo; se responde `stale`.
5. **Prioridad de los datos.** El **servidor es la fuente de verdad**: tras sincronizar, la copia local se reemplaza con su estado, **salvo** las claves con operaciones aún pendientes (la intención local más reciente se respeta hasta enviarse). El historial es de sólo inserción: es la unión de lo del servidor y las entradas locales no enviadas.
6. **Cuándo se sincroniza.**
   - Al iniciar la app o la sesión.
   - Al **recuperar la conexión** (`connectivity_plus`).
   - Tras cada cambio local.
   - Con el botón ⟳.

   Si falla, reintenta con espera exponencial (2, 4, 8, 16 y 32 s); después espera a la siguiente reconexión. La barra superior muestra el estado, los cambios en cola y la **última sincronización**.

**Qué sigue disponible al cerrar y volver a abrir la app sin Internet:**

| Dato | Dónde se guarda |
|---|---|
| Sesión (JWT y usuario) | Keystore/Keychain vía `flutter_secure_storage` |
| Tareas | SQLite, sólo lectura sin red |
| Búsquedas y resultados ya consultados | SQLite |
| Detalle de libros abiertos | SQLite |
| Favoritos e historial | SQLite, separados por `user_id` |
| Cola pendiente | SQLite |
| Últimas recomendaciones y su criterio | SQLite |

Las portadas se descargan de internet y sin red se muestra un ícono en su lugar. No se requiere iniciar sesión con Google por primera vez sin conexión.

## 4. Recomendaciones

Regla reproducible, sin IA. Está en [`recommendation_engine.dart`](app/lib/services/recommendation_engine.dart) y tiene pruebas unitarias.

1. **Perfil:** cada tema y autor de un **favorito suma 3**. Cada tema y autor de los 5 primeros resultados de una **búsqueda** del historial **suma 1**. Se descartan temas genéricos ("Fiction", "Accessible book", etc.).
2. **Semillas:** los **2 temas** y el **autor** con más puntos. Los empates se ordenan alfabéticamente.
3. **Candidatos:** se consulta Open Library por esos temas y ese autor, y se suman los resultados guardados del historial. Se **excluyen los favoritos**.
4. **Puntaje:** suma de los puntos de los temas y autores que coinciden. El orden es puntaje, luego ediciones y luego título. Se muestran hasta 10, cada uno con su explicación ("Coincide en autor: … · temas: …").
5. **Sin historial ni favoritos:** sugerencias iniciales del tema *classic literature*, con un mensaje que lo explica.
6. El resultado y su criterio se **guardan en SQLite** para verlos sin conexión.

## 5. Seguridad

- **HTTPS en todo:** Render, Open Library y Google. El tráfico sin cifrar sólo se permite en el emulador con compilación debug (`network_security_config` de `src/debug`).
- **Tokens:**
  - El JWT se guarda en almacenamiento seguro.
  - El ID token de Google no se guarda: sólo se envía una vez al backend.
  - `POST /logout` revoca el JWT.
- **Autorización en el backend:**
  - `admin_required` lee el rol de la BD en cada petición (no confía en el claim del token ni en la UI).
  - Todas las consultas de `/me/*` filtran por el usuario del token.
  - La BD local filtra por `user_id`.
- **Sin secretos en el repo:**
  - Se ignoran `.env`, `config/*.json` y `GoogleOAuth.xcconfig`.
  - CI usa *Secrets* y *Variables* de GitHub.

## 6. Documentación y evidencias

- [Informe técnico](docs/informe_tecnico.md)
- [Matriz de pruebas](docs/matriz_pruebas.md)
- Evidencias: artefactos `evidencias-android` y `evidencias-ios` de GitHub Actions, más las capturas manuales en `docs/evidencias/`.

### Integrantes y contribuciones
| Integrante | Contribución |
|---|---|
| María Guadalupe Hernández Alvirde | Todo el proyecto |

### Herramientas de IA utilizadas
Se usó **Claude (Anthropic) mediante Claude Code** como asistente para:
- generar código del backend y de la app;
- escribir las pruebas automatizadas;
- preparar el workflow de CI;
- redactar la documentación.

Todo fue revisado, ejecutado y validado por la autora.

---

## English version

**Biblioteca ESCOM** is a single **Flutter** app for **Android 7.0+ (API 24)** and **iOS 15+**. It extends [Practice 2 (commit `dcdab0e`)](https://github.com/hernandezalvirdemariaguadalupe-cyber/AplicacionesMoviles/tree/dcdab0e/practica2): same Flask backend, task CRUD and JWT login. New features:

- **Open Library** search, detail view, search history and favorites.
- **Google Sign-In**, with the ID token verified on the server.
- **Admin role**, enforced by the backend.
- **Offline-first** storage: SQLite, a pending-operation queue and idempotent sync with exponential-backoff retries.
- Reproducible, persisted **recommendations**.

### Requirements
- Flutter 3.50+
- Android Studio with an emulator
- Docker or Python 3.12 for the backend
- macOS/Xcode only for local iOS builds. Otherwise the GitHub Actions `macos-latest` job builds the app, boots an iPhone simulator, runs the same E2E test as Android and uploads screenshots and video.

### Run
```bash
# Backend
cd practica5/backend && cp .env.example .env && docker compose up --build
#   or: pip install -r requirements-dev.txt && python -m pytest && python run.py
# Production HTTPS: Render Blueprint using /render.yaml (web service + free Postgres)

# App
cd practica5/app && cp config/example.json config/dev.json   # fill in API URL and OAuth client IDs
flutter run --dart-define-from-file=config/dev.json            # Android
flutter run -d "iPhone 16" --dart-define-from-file=config/dev.json   # iOS (macOS only)
```

### API / OAuth configuration without secrets
- Every value comes from environment variables (backend) or `--dart-define-from-file` (app). The `.env`, `config/*.json` and `ios/Flutter/GoogleOAuth.xcconfig` files are git-ignored.
- Create three OAuth clients in Google Cloud:
  - **Web:** server audience.
  - **Android:** package name + SHA-1.
  - **iOS:** bundle ID + reversed URL scheme.

### Endpoints
- **Reused from Practice 2:** `/register`, `/login`, `/tasks` CRUD.
- **New:** `/auth/google`, `/me`, `/logout`, `/me/favorites`, `/me/history`, `/me/sync`, `/admin/*`. Non-admins get **403**.

### Sync and conflict strategy
1. Writes go to SQLite first and are enqueued with a UUID `op_id`. The queue keeps only the latest intent per book.
2. `POST /me/sync` is idempotent: processed `op_id`s are stored, so retries after a lost response return `duplicate`. Operations leave the queue only after the server confirms them, so nothing is lost or duplicated.
3. Favorites use last-write-wins with tombstones. Late, older operations are reported as `stale`.
4. The server is the source of truth, except for keys that still have pending local operations.
5. Sync runs on app start, on reconnection, after each local change and on demand, with retries at 2, 4, 8, 16 and 32 s.
6. Available offline after a restart: session (secure storage), tasks (read-only), cached searches and book details, favorites, history, pending queue and last recommendations.

### Recommendations
Interest profile: favorite subjects and authors weigh ×3, search-history results weigh ×1. The app then:
1. Takes the top 2 subjects and the top author as seeds.
2. Queries Open Library for them and excludes favorites.
3. Ranks candidates by matching weight, then edition count, then title.
4. Shows each one with an explanation and persists the result.

Users with no data get *classic literature* starter picks.

### Docs
- [Technical report (ES)](docs/informe_tecnico.md)
- [Test matrix (ES)](docs/matriz_pruebas.md)

**AI tools:** Claude (Anthropic) via Claude Code was used as a coding and documentation assistant. All output was reviewed and validated by the author.
