# Informe técnico: Práctica 5

**Consulta de bases de datos vía APIs y funcionalidades específicas en aplicaciones multiplataforma (Android e iOS)**

María Guadalupe Hernández Alvirde · 2022630105 · 5CV4 · Desarrollo de aplicaciones móviles nativas · ESCOM-IPN

---

## 1. Introducción

En la Práctica 2 se construyó una API REST en Flask (dockerizada) con registro, login con JWT y un CRUD de tareas, consumida por una app Android nativa (Kotlin + Jetpack Compose + Retrofit). Ese cliente no funcionaba en iOS.

En esta práctica el cliente se **reconstruyó como una sola aplicación Flutter** que se ejecuta en Android e iOS con el mismo código. También se ampliaron backend y app con:

- consumo de una API pública (Open Library);
- historial de búsquedas y favoritos por usuario;
- recomendaciones;
- inicio de sesión con Google;
- rol administrador;
- funcionamiento sin conexión con sincronización controlada.

Se eligió **Flutter** sobre Kotlin Multiplatform por tres razones:

1. El entorno ya tenía Flutter configurado.
2. Toda la interfaz y la lógica quedan en un solo lenguaje (Dart).
3. Sin una Mac disponible, la compilación y prueba en iOS se automatiza más fácil en la nube (GitHub Actions con `macos-latest`).

## 2. Arquitectura

```
┌──────────────────────────── App Flutter (Dart, código común) ─────────────────────────────┐
│  UI (Material 3)  ─►  AppState (ChangeNotifier/Provider: sesión, red, sync, reintentos)    │
│                          │                                                                 │
│      ┌───────────────────┼───────────────────────┬───────────────────────┐                 │
│  AuthRepository     TaskRepository        LibraryRepository        BooksRepository         │
│  (login, Google)    (CRUD P2)             (favoritos, historial,   (Open Library +         │
│                                            cola, /me/sync)          caché)                 │
│      │                   │                       │                       │                 │
│  ApiClient (Dio, JWT, errores normalizados)       │              RecommendationService      │
│      │                                            │              + RecommendationEngine     │
│  SessionStore (flutter_secure_storage)      LocalDb (sqflite)                              │
└──────┼──────────────────────────────────────────────────────────────────────────────────────┘
       │ HTTPS                                                    │ HTTPS
       ▼                                                          ▼
 Backend Flask (Render, Docker, gunicorn)                 openlibrary.org / covers
  /register /login /tasks  (P2)                           accounts.google.com (OAuth)
  /auth/google /me /logout /me/* /admin/*  (P5)
  SQLAlchemy ► Postgres (Render) | SQLite (local)
```

**Componentes comunes (Dart, 100 % compartido):**
- UI;
- estado;
- repositorios;
- cliente HTTP (Dio);
- base de datos local (sqflite);
- motor de recomendaciones;
- manejo de errores.

**Componentes nativos y configuración por plataforma:**

| Aspecto | Android | iOS |
|---|---|---|
| Almacenamiento seguro | Android Keystore (EncryptedSharedPreferences) | Keychain |
| Google Sign-In | Credential Manager; cliente OAuth "Android" con paquete + SHA-1 | GoogleSignIn SDK; cliente OAuth "iOS", `GIDClientID` y URL scheme invertido en `Info.plist` (vía `GoogleOAuth.xcconfig`) |
| Red | Permisos `INTERNET` y `ACCESS_NETWORK_STATE`; `network_security_config` sólo en debug | ATS (HTTPS obligatorio por defecto) |
| Versión mínima | `minSdk = 24` (Android 7.0) | `IPHONEOS_DEPLOYMENT_TARGET = 15.0` |
| Conectividad | `ConnectivityManager` | `NWPathMonitor` (vía `connectivity_plus`) |

## 3. Endpoints usados

**Backend propio:**

| Endpoint | Origen | Uso en la app |
|---|---|---|
| `POST /register`, `POST /login` | Práctica 2 | Registro y login con usuario y contraseña |
| `GET/POST /tasks`, `GET/PUT/DELETE /tasks/<id>` | Práctica 2 | Pestaña *Tareas* (CRUD completo) |
| `POST /auth/google` | Nuevo | Recibe el ID token, lo valida con las llaves públicas de Google (`google-auth`) y comprueba `aud`, `iss`, expiración y `email_verified`. Crea o vincula la cuenta y emite el JWT |
| `GET /me` | Nuevo | Restaurar la sesión al abrir la app |
| `POST /logout` | Nuevo | Revocar el JWT (JTI en `revoked_tokens`) |
| `GET /me/favorites`, `PUT/DELETE /me/favorites/<key>` | Nuevo | Favoritos (REST directo) |
| `GET/POST/DELETE /me/history` | Nuevo | Historial |
| `POST /me/sync` | Nuevo | Aplicar la cola offline y devolver el estado del servidor |
| `GET /admin/users`, `/admin/users/<id>/history`, `/admin/users/<id>/favorites`, `PATCH /admin/users/<id>/role` | Nuevo | Panel de administrador. Si no eres admin: **403** |

**Open Library:**

| Endpoint | Uso |
|---|---|
| `GET /search.json?q=…&fields=…&limit=20` | búsqueda por texto |
| `GET /search.json?subject=…` y `?author=…` | candidatos para recomendaciones |
| `GET /works/{OLID}.json` | detalle: descripción y temas |
| `https://covers.openlibrary.org/b/id/{id}-{S\|M}.jpg` | portadas |

## 4. Modelo de datos

**Servidor (SQLAlchemy):**

| Tabla | Campos clave |
|---|---|
| `users` | `id`, `username`, `password_hash` (nullable para cuentas Google), `email`, `google_sub`, `display_name`, `role` (`user`/`admin`) |
| `tasks` | igual que en la Práctica 2 |
| `search_history` | `user_id`, `client_id` (UUID del dispositivo, único por usuario), `query`, `results_count`, `created_at` |
| `favorites` | `user_id`, `work_key` (único por usuario), `title`, `authors_json`, `subjects_json`, `cover_id`, `first_publish_year`, `deleted` (*tombstone*), `updated_at` |
| `processed_operations` | `user_id`, `op_id` (único), `status`. Garantiza idempotencia |
| `revoked_tokens` | `jti` |

**Dispositivo (SQLite, `LocalDb`):**

| Tabla | Contenido |
|---|---|
| `tasks` | copia de lectura de las tareas |
| `search_cache` | resultados de búsqueda y fecha |
| `books` | detalle de los libros abiertos |
| `history` | historial, con bandera `synced` |
| `favorites` | favoritos |
| `pending_ops` | cola FIFO de operaciones pendientes |
| `recommendations` | último resultado y su criterio |
| `meta` | última sincronización y última actualización de tareas |

Todas las tablas con datos personales usan `user_id` en la llave primaria.

## 5. Persistencia y sincronización

Ver la sección 3 del [README](../README.md#3-sincronización-y-estrategia-de-conflictos).

En resumen:
- **local primero** con cola compactada;
- `op_id` idempotente en el servidor;
- **last-write-wins** con *tombstones* para favoritos;
- el servidor es la fuente de verdad salvo para cambios aún pendientes;
- sincronización al iniciar, al reconectar, tras cada cambio y manual;
- reintentos exponenciales (2 a 32 s, 5 intentos).

**Cómo se evitan pérdidas y duplicados.** Una operación sólo se borra de la cola cuando el servidor devuelve un estado para su `op_id`. Si la respuesta se pierde, la app reenvía el mismo `op_id` y el servidor contesta `duplicate` sin aplicarla de nuevo. La prueba unitaria `respuesta perdida + reintento = sin duplicados ni pérdidas` y la prueba de backend `test_sync_es_idempotente` lo verifican.

## 6. Autenticación

1. **Usuario y contraseña** (Práctica 2): bcrypt y JWT HS256. El token expira en 24 h (configurable).
2. **Google:**
   1. `google_sign_in` 7 obtiene un **ID token** cuya audiencia es el client ID *Web* (`serverClientId`).
   2. El backend lo verifica criptográficamente con las llaves públicas de Google.
   3. Busca la cuenta por `google_sub` (o la vincula por correo verificado).
   4. Emite su **propio JWT**.

   El ID token nunca se guarda en el dispositivo.
3. **Sesión segura:**
   - El JWT y el perfil se guardan en Keystore/Keychain.
   - Al abrir la app se valida con `GET /me`. Sin red se conserva la sesión ya validada para consultar datos locales.
   - Si el servidor responde 401, la sesión se cierra.
   - `POST /logout` revoca el token y se cierra también la sesión de Google.
4. **Autorización:**
   - El decorador `admin_required` lee el rol desde la BD en cada petición.
   - Las rutas `/me/*` filtran por el `user_id` del token.
   - Pruebas: `test_admin_autorizado_y_usuario_denegado`, `test_usuario_no_puede_escalar_rol_desde_el_cliente` y `test_datos_aislados_por_usuario`.

## 7. Recomendaciones

Regla reproducible, explicada en la app y en el README (sección 4):

- favoritos ×3, búsquedas ×1;
- semillas: los 2 temas y el autor con más puntos;
- candidatos de Open Library sin los favoritos;
- orden por puntaje, luego ediciones y luego título.

Sin datos se muestran clásicos populares. El resultado se guarda en SQLite y se puede consultar sin conexión. Pruebas en `test/recommendation_engine_test.dart`.

## 8. Resultados

> Completar con los resultados reales de la [matriz de pruebas](matriz_pruebas.md) y las capturas de `docs/evidencias/` y de los artefactos de GitHub Actions.

- **Pruebas automáticas del backend:** 10 casos `pytest` (CRUD de la P2, Google, logout, idempotencia, LWW, aislamiento por usuario, admin/403).
- **Pruebas unitarias de la app:** 10 casos `flutter test` (recomendaciones, parseo y datos malformados, clasificación de errores HTTP, cola y sincronización).
- **Prueba funcional E2E:** 9 escenarios, más el de administrador si se configuran las credenciales. Se ejecuta igual en Android (emulador API 24 en CI y emulador local) y en el simulador de iPhone (GitHub Actions, macOS).

## 9. Conclusiones

> Redactar con la experiencia propia. Puntos sugeridos:

- Escribir primero en local y encolar con identificadores únicos hace que la app responda igual con o sin red, y que los reintentos sean seguros.
- La autorización debe vivir en el servidor: ocultar el botón de administrador no basta (se demostró con el 403).
- Flutter permitió compartir el 100 % de la lógica y la UI. Lo específico de cada plataforma se redujo a configuración (OAuth, permisos, almacenamiento seguro).
- No contar con macOS se resolvió con CI en la nube, a cambio de no poder probar a mano en un iPhone físico.

## 10. Referencias (APA 7)

- Flutter. (2026). *Flutter documentation*. Google. https://docs.flutter.dev/
- Google. (2026). *Authenticate with a backend server*. Google Identity. https://developers.google.com/identity/sign-in/android/backend-auth
- Google. (2026). *google_sign_in* (Versión 7.2.0) [Paquete de software]. pub.dev. https://pub.dev/packages/google_sign_in
- Internet Archive. (2026). *Open Library developers: APIs*. https://openlibrary.org/developers/api
- Pallets Projects. (2024). *Flask documentation* (Versión 3.0). https://flask.palletsprojects.com/
- Render. (2026). *Blueprint specification*. https://render.com/docs/blueprint-spec
- Tekartik. (2026). *sqflite* [Paquete de software]. pub.dev. https://pub.dev/packages/sqflite
- Kleppmann, M. (2017). *Designing data-intensive applications*. O'Reilly Media.
