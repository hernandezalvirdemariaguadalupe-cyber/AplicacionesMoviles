# Aplicaciones Móviles - Práctica 1

Instalación y Funcionamiento de los Entornos Móviles.
Instituto Politécnico Nacional — Escuela Superior de Cómputo.
Ingeniería en Sistemas Computacionales / Desarrollo de aplicaciones móviles nativas.

**Nombre completo:** _[completar]_
**Número de boleta:** _[completar]_
**Grupo:** _[completar]_

## Estructura del repositorio

```
AplicacionesMoviles/
├── hola_mundo_xml/       # Versión 1: Android nativo con Views (XML), Kotlin
├── hola_mundo_compose/   # Versión 2: Android nativo con Jetpack Compose
└── hola_mundo_flutter/   # Versión 3: Flutter
```

Cada carpeta contiene un proyecto independiente con su propio `.gitignore`.

## Herramientas instaladas

| Herramienta | Descripción | Versión instalada | Sistema operativo |
|---|---|---|---|
| Android Studio | IDE oficial para desarrollo Android, incluye el emulador. | _[completar]_ | _[completar]_ |
| JDK (Amazon Corretto) | Distribución de OpenJDK usada para compilar y ejecutar Java/Kotlin. | _[completar]_ | _[completar]_ |
| Maven | Automatiza la construcción de proyectos y gestión de dependencias. | _[completar]_ | _[completar]_ |
| Git | Control de versiones. | _[completar]_ | _[completar]_ |
| Flutter SDK | SDK de Google para apps multiplataforma. | _[completar]_ | _[completar]_ |
| Node.js | Entorno de ejecución de JavaScript del lado del servidor. | _[completar]_ | _[completar]_ |
| Docker | Plataforma de contenedores. | _[completar]_ | _[completar]_ |

## Descripción de los tres proyectos

### 1. `hola_mundo_xml` — Android nativo con Views (XML)
Proyecto creado con la plantilla *Empty Views Activity* (Kotlin). La interfaz se define en un layout XML
usando `ConstraintLayout`/`LinearLayout` y `TextView` para mostrar "Hola Mundo", nombre, boleta y grupo.

**Cómo ejecutarlo:**
1. Abre la carpeta `hola_mundo_xml` en Android Studio.
2. Espera a que sincronice Gradle.
3. Ejecuta con el botón ▶️ Run sobre un emulador o dispositivo físico.

### 2. `hola_mundo_compose` — Android nativo con Jetpack Compose
Proyecto creado con la plantilla *Empty Activity (Compose)*. Un composable propio muestra la información
mediante `Text` dentro de un `Column`/`Surface`, con al menos un modificador de estilo aplicado.

**Cómo ejecutarlo:**
1. Abre la carpeta `hola_mundo_compose` en Android Studio.
2. Espera a que sincronice Gradle.
3. Usa `@Preview` para verlo en el IDE, o ejecuta con ▶️ Run sobre un emulador o dispositivo físico.

### 3. `hola_mundo_flutter` — Flutter
Proyecto generado con `flutter create hola_mundo_flutter`. `lib/main.dart` usa `MaterialApp`, `Scaffold`
y widgets `Text`/`Column` para mostrar la información solicitada.

**Cómo ejecutarlo:**
```bash
cd hola_mundo_flutter
flutter pub get
flutter run
```

## Capturas de pantalla

### Proceso de instalación y configuración
_[Captura: Android Studio + emulador ejecutando "Hello Android"]_

_[Capturas: terminal con `java -version`, `mvn -v`, `git --version`, `flutter doctor`, `node -v`, `docker --version`]_

### Aplicaciones en ejecución
_[Captura: hola_mundo_xml corriendo]_

_[Captura: hola_mundo_compose corriendo]_

_[Captura: hola_mundo_flutter corriendo]_

### Historial de commits
_[Captura: historial de commits del repositorio]_

## Dificultades encontradas y solución

_[completar: por ejemplo, problemas de PATH con Flutter, licencias de Android no aceptadas, versión de JDK incompatible con Gradle, etc., y cómo se resolvieron]_

## Comparación entre los tres enfoques

_[completar: máximo media cuartilla — facilidad de desarrollo, cantidad de código y diferencias en el diseño de la interfaz entre Views/XML, Jetpack Compose y Flutter]_

## Conclusiones

_[completar: hallazgos del proceso de instalación y de la comparación entre los tres enfoques]_
