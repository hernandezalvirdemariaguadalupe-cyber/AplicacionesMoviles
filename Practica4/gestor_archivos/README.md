# Parte 1 — Gestor de Archivos Multiplataforma (Flutter)

Gestor de archivos para **Android 7.0+ (API 24)** e **iOS 15+** que trabaja sólo con
ubicaciones a las que la app tiene acceso legítimo. Funciona 100 % sin conexión.

## Tecnología y versiones

| Elemento | Versión |
|---|---|
| Flutter | 3.50.0 (canal stable) |
| Dart | 3.14.0 |
| Android | minSdk 24, compileSdk/targetSdk = los de Flutter 3.50 (SDK 36) |
| iOS | Deployment target 15.0 |

### Dependencias

| Paquete | Uso |
|---|---|
| `provider` | Estado global (tema, recientes, favoritos, portapapeles) |
| `shared_preferences` | Persistencia de tema, recientes, favoritos y ubicaciones (SharedPreferences / NSUserDefaults) |
| `path_provider` | Directorio privado de la app y caché |
| `share_plus` | Compartir archivos con el menú del sistema |
| `xml` | Validar y formatear XML |
| `mime`, `path` | Tipo MIME por extensión y manejo de rutas |

El resaltado de sintaxis de JSON/XML/Markdown, la caché de miniaturas y el acceso SAF /
Document Picker están implementados en el propio proyecto (sin librerías externas).

## Arquitectura

```
lib/
├── main.dart                 # MaterialApp, temas y navegación adaptable (barra / rail)
├── core/                     # Temas Guinda/Azul, errores legibles, formato
├── data/
│   ├── native_storage.dart   # MethodChannel "mx.ipn.escom/storage" → código nativo
│   ├── storage_service.dart  # API única: dart:io (rutas) o SAF (content://)
│   ├── thumbnail_cache.dart  # Caché de miniaturas en memoria (LRU) + disco
│   ├── app_state.dart        # Persistencia de recientes, favoritos, ubicaciones, tema
│   └── sample_files.dart     # Archivos de ejemplo generados la primera vez
└── ui/                       # Explorar, explorador con breadcrumbs, visores, ajustes
```

### Código específico por plataforma

* **Android** — `android/app/src/main/kotlin/.../MainActivity.kt`
  * `ACTION_OPEN_DOCUMENT_TREE` / `ACTION_OPEN_DOCUMENT` + `takePersistableUriPermission`.
  * Listado, creación, renombrado y borrado con `DocumentsContract` respetando los
    `FLAG_SUPPORTS_*` del proveedor.
  * `ACTION_CREATE_DOCUMENT` para exportar y `FileProvider` para "Abrir con".
  * **No** se declara ningún permiso de almacenamiento (Scoped Storage).
* **iOS** — `ios/Runner/AppDelegate.swift` (`StoragePlugin`)
  * `UIDocumentPickerViewController` para carpetas (`.folder`) y archivos (`.item`).
  * Recursos *security-scoped* + **bookmarks** para recuperar el acceso entre sesiones.
  * `UTType` para el tipo de archivo, `UIDocumentInteractionController` para "Abrir con".
  * `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`: la carpeta de la app
    aparece en la app Archivos.

## Compilar y ejecutar

### Android (Windows, macOS o Linux)

```bash
cd Practica4/gestor_archivos
flutter pub get
flutter emulators --launch <id_emulador>   # o conecta un teléfono con depuración USB
flutter run
```

APK de depuración: `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`.

### iOS (requiere macOS con Xcode)

1. Instalar Xcode desde la App Store y abrirlo una vez para aceptar la licencia.
2. `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
3. `sudo xcodebuild -runFirstLaunch`
4. Instalar CocoaPods: `brew install cocoapods` (o `sudo gem install cocoapods`).
5. Abrir un simulador: `open -a Simulator` (iPhone con iOS 15 o superior).
6. En el proyecto:
   ```bash
   cd Practica4/gestor_archivos
   flutter pub get
   cd ios && pod install && cd ..
   flutter run
   ```
7. Para un iPhone físico: abrir `ios/Runner.xcworkspace` en Xcode → *Signing & Capabilities*
   → elegir tu *Team* (Apple ID gratuito) y cambiar el Bundle Identifier si es necesario.
