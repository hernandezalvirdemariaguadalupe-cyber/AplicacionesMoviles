# Matriz de pruebas: Práctica 5

Las mismas pruebas funcionales se ejecutan en ambas plataformas. Llena la columna **Resultado obtenido** y enlaza la captura correspondiente.

## Dispositivos

| Plataforma | Dispositivo / simulador | Sistema operativo | Cómo se ejecutó |
|---|---|---|---|
| Android | Emulador `Medium_Phone_API_37.0` | Android (API 37) | `flutter drive` local + pruebas manuales |
| Android | Emulador Pixel 4, CI | Android 7.0 (API 24) | GitHub Actions, job `android-e2e` |
| iOS | **Simulador** de iPhone, CI (modelo y versión en `device-ios.txt` del artefacto) | iOS 18.x / 26.x (según el runner) | GitHub Actions, job `ios-e2e` (`macos-latest`) |

> Las pruebas de iOS se hicieron en **simulador** (permitido por la práctica), por no contar con una Mac.

## Escenarios

En la columna Auto, **E2E** quiere decir que lo cubre la prueba automatizada `integration_test/app_test.dart` (con captura) y **Manual** que se prueba a mano.

| # | Escenario | Pasos | Resultado esperado | Auto | Android: obtenido / captura | iOS: obtenido / captura |
|---|---|---|---|---|---|---|
| 1 | Consulta REST: registro, login y CRUD (P2) | Registrar usuario → entrar → *Tareas* → **+** crear → marcar completada (PUT) → borrar (DELETE) → deslizar para recargar (GET) | Se crea, actualiza y elimina. Se muestra "Cargado en N ms" | E2E (crear) + Manual | | |
| 2 | Búsqueda pública | *Buscar* → "tolkien hobbit" → abrir un resultado | Lista de Open Library con portada, autor y año. El detalle muestra descripción y temas | E2E | | |
| 3 | Estado vacío y errores | Buscar "zzqxwvkj…" · con el modo avión, buscar un término nuevo · backend apagado | "Sin resultados…" · "Sin conexión" con botón Reintentar · "Error del servidor (HTTP …)". La app nunca se cierra | E2E (vacío) + Manual | | |
| 4 | Google: acceso y cierre de sesión | *Continuar con Google* → elegir cuenta → *Perfil* → *Cerrar sesión* | Entra con "Acceso: Google". Al cerrar vuelve al login | Manual | | |
| 5 | Favoritos | Detalle → ♥ → *Favoritos* → quitar ♥ | Aparece y desaparece. Persiste tras reiniciar | E2E | | |
| 6 | Recomendaciones | Con favoritos → *Para ti* → *Generar* · con cuenta nueva → *Generar* | ≥3 libros con su explicación y puntos, más la tarjeta del criterio · sin datos: "Sugerencias iniciales" | E2E | | |
| 7 | Reinicio de la app | Cerrar la app por completo → abrir | La sesión se restaura sin pedir login. Favoritos, historial y recomendaciones siguen ahí | Manual | | |
| 8 | Consulta offline | Activar el modo avión → reabrir la app → ver *Favoritos*, *Perfil > Historial*, *Tareas*, *Para ti* y repetir una búsqueda previa | Todo se muestra desde SQLite ("Copia local guardada el…"). La barra superior dice "Sin conexión" | E2E (parcial) + Manual | | |
| 9 | Reconexión y sincronización | Sin red: marcar 2 favoritos y quitar 1 → barra: "N cambios en cola" → activar la red | Se sincroniza solo. "Cambios pendientes: 0". La hora de la última sincronización se actualiza. En otro dispositivo o en el admin no hay duplicados | E2E + Manual | | |
| 10 | Admin autorizado | Entrar con la cuenta admin → *Perfil* → *Panel de administrador* → elegir un usuario | Se ven el historial y los favoritos de ese usuario | E2E (con credenciales) + Manual | | |
| 11 | Acceso denegado | Con una cuenta normal → *Perfil* → *Probar acceso a /admin/users* | "Acceso denegado (HTTP 403)" | E2E | | |
| 12 | Aislamiento por cuenta | Cuenta A marca favoritos → cerrar sesión → entrar con la cuenta B | B no ve los favoritos ni el historial de A | Manual | | |

## Demostración de conectividad en tiempo real (para el video)

1. Abre la app con sesión iniciada y pon a la vista la barra superior (ícono de nube).
2. Activa el **modo avión**. La barra cambia a "Sin conexión · 0 cambios en cola".
3. Abre 2 libros y márcalos como favoritos. La barra muestra "2 cambios en cola" y en *Perfil* las búsquedas aparecen como "pendiente".
4. Desactiva el modo avión. La barra muestra "Sincronizando (reconexión)…" y luego "Sincronizado: enviadas N · aplicadas N…".
5. Con la cuenta admin, revisa que el usuario tenga exactamente esos favoritos, sin duplicados.

**Por qué no se pierden ni duplican datos:** las operaciones sólo salen de la cola cuando el servidor confirma su `op_id`, y el servidor ignora los `op_id` que ya procesó. Las pruebas `respuesta perdida + reintento` (app) y `test_sync_es_idempotente` (backend) lo verifican.

## Pruebas automatizadas

| Suite | Comando | Casos | Resultado |
|---|---|---|---|
| Backend (pytest) | `python -m pytest -v` | 10 | ✅ 10/10 (local, Python 3.12, Windows) |
| App unitarias | `flutter test` | 10 | ✅ 10/10 (local, Windows) |
| E2E Android | `flutter drive … -d emulator-5554` | 1 flujo / 10 escenarios (con admin) | ✅ aprobado en emulador `Medium_Phone_API_37.0` (Android 17), 12 capturas en [`evidencias/android`](evidencias/android) |
| E2E Android vs Render (HTTPS) | `flutter drive … --dart-define-from-file=config/render.json` | 1 flujo / 9 escenarios | ✅ aprobado contra `https://practica5-api.onrender.com`, 11 capturas en [`evidencias/android_render`](evidencias/android_render) |
| E2E iOS | GitHub Actions `ios-e2e` | 1 flujo / 9 escenarios | |

## Defectos (issues)

| Issue | Descripción | Plataforma | Estado |
|---|---|---|---|
| | | | |
