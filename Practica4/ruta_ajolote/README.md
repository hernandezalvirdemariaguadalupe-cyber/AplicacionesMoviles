# Parte 2 — Ruta del Ajolote (Flutter)

Juego original para **Android 7.0+ (API 24)** e **iOS 15+**, 100 % sin conexión. Un ajolote
recorre los canales de Xochimilco recolectando burbujas de oxígeno.

| Elemento | Función |
|---|---|
| 🫧 Burbuja | +10 puntos |
| 🪨 Piedra | Bloquea el paso (no cuenta movimiento) |
| 🌀 Remolino | −1 vida y regresa al inicio |
| ➤ Corriente | Empuja una casilla extra en su dirección |
| 🚪 Compuerta | Meta de Aventura; sólo abre con todas las burbujas |

## Modos de juego

* **Aventura** — 5 niveles diseñados a mano con límite de movimientos, estrellas (1-3),
  récord por nivel y desbloqueo progresivo. Una prueba automática (BFS) verifica que cada
  nivel tiene solución dentro de su límite.
* **Contrarreloj** — mapas aleatorios reproducibles por semilla; cada mapa despejado da
  +50 puntos y +10 s.

Controles: deslizar sobre el tablero, cruceta en pantalla o flechas/WASD del teclado.
Efectos: animación del recorrido, ondas de agua, remolinos girando, partículas al reventar
burbujas, destello y sacudida al recibir daño, y sonidos sintetizados (WAV generado en el
dispositivo) con vibración.

## Gestión de archivos

* Guardado en **TXT (formato INI), XML y JSON**; el formato predeterminado se elige en
  Opciones y también al guardar.
* Cada archivo contiene: estado del juego (mapa, posición, inicio, estado), puntuación,
  tiempo transcurrido/restante, configuración personalizada e **historial de movimientos**.
* Los tres formatos pasan por la **misma validación** (`lib/save/codec.dart`): archivos
  vacíos, incompletos (p. ej. TXT sin `[FIN]`, XML sin cerrar) o con datos inválidos
  (filas de distinto ancho, posición sobre una piedra, historial dañado) muestran un error
  legible y **no afectan a las demás partidas**.
* Almacenamiento predeterminado: carpeta privada de la app (`Application Support/partidas`).
  Escritura atómica (temporal + renombrar).
* **Autoguardado** tras cada movimiento y al pasar a segundo plano → "Continuar" al reabrir.
* Lista de partidas con metadatos, filtros por formato y **etiquetas**, visor del contenido
  con resaltado, historial de movimientos, copia a otro formato, **exportar** (SAF /
  Document Picker), **compartir** e **importar** (validando antes de copiar).

## Arquitectura

```
lib/
├── game/        model.dart · engine.dart (reglas puras, sin Flutter) · levels.dart
├── save/        codec.dart (TXT/XML/JSON) · repository.dart · native_files.dart
├── core/        theme.dart (Guinda/Azul, claro/oscuro) · sound.dart
├── ui/          home · game_screen · board (CustomPainter) · saves · save_viewer · options
└── app_state.dart  preferencias y progreso (SharedPreferences / NSUserDefaults)
test/            engine_test.dart (niveles resolubles, reglas) · codec_test.dart (formatos)
```

Código específico por plataforma:
* Android — `MainActivity.kt`: `ACTION_CREATE_DOCUMENT` (exportar) y `ACTION_OPEN_DOCUMENT`
  (importar). Sin permisos de almacenamiento.
* iOS — `AppDelegate.swift` (`ArchivosPlugin`): `UIDocumentPickerViewController` para
  exportar (`forExporting`) e importar (`forOpeningContentTypes`, `asCopy`).

## Compilar y ejecutar

```bash
cd Practica4/ruta_ajolote
flutter pub get
flutter test          # 23 pruebas: niveles, reglas y formatos
flutter run           # con un emulador Android o simulador iOS abierto
```

iOS: mismos pasos de preparación de Xcode/CocoaPods descritos en
`../gestor_archivos/README.md`, luego `cd ios && pod install && cd .. && flutter run`.
