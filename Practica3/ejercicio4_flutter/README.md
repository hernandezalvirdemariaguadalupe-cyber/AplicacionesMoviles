# Ejercicio 4: Gestor de Archivos Multiplataforma en Flutter

## Instituto Politécnico Nacional — Escuela Superior de Cómputo
**Asignatura:** Desarrollo de Aplicaciones Móviles Nativas  
**Grupo:** 7CV4 | **Semestre:** 2027-1  
**Integrantes:**
- Hernández Alvirde María Guadalupe (Boleta: 2022630105)
- Aragón Martínez Manuel Alejandro

---

## 📱 Descripción del Proyecto

Aplicación móvil multiplataforma desarrollada con **Flutter** y **Dart** para los sistemas operativos **Android** e **iOS**, diseñada bajo los lineamientos de **Clean Architecture** y principios de diseño **Material Design 3**.

La aplicación funciona de manera **100% autónoma y sin conexión a Internet (offline)**, administrando los archivos y carpetas dentro del sandbox local del dispositivo.

---

## 🏛️ Temas Institucionales y Personalización

La aplicación implementa los esquemas de color oficiales institucionales:

1. **Tema Guinda IPN:**
   - Color Primario: `#6C1D45` (Guinda Oficial IPN - Pantone 222 C)
   - Color Secundario: `#D4AF37` (Oro)
2. **Tema Azul ESCOM:**
   - Color Primario: `#003366` (Azul Oficial ESCOM - Pantone 295 C)
   - Color Secundario: `#0099FF` (Azul Celeste)

Ambos esquemas admiten de forma dinámica:
- **Modo Claro**
- **Modo Oscuro**
- **Modo Automático** (adaptado al tema del sistema del dispositivo)

La preferencia de tema y modo se almacena de forma persistente en el dispositivo mediante `SharedPreferences`.

---

## 🏗️ Arquitectura del Software (Clean Architecture)

El código fuente está modularizado siguiendo una separación de responsabilidades limpia:

```text
lib/
├── core/
│   ├── constants/
│   │   └── app_colors.dart         # Paletas de color IPN y ESCOM
│   └── theme/
│       └── theme_provider.dart     # Gestión de temas y persistencia SharedPreferences
├── data/
│   ├── models/
│   │   └── file_item.dart          # Modelo de entidad de archivo/directorio
│   └── repositories/
│       └── file_repository.dart    # Acceso a filesystem local (dart:io y sandbox)
├── presentation/
│   ├── providers/
│   │   └── file_manager_provider.dart # Estado global de navegación, filtros y CRUD
│   ├── screens/
│   │   ├── home_screen.dart        # Vista principal del explorador
│   │   ├── text_viewer_screen.dart # Lector y editor de archivos de texto plano
│   │   ├── image_viewer_screen.dart# Visor interactivo con zoom (pinza) y rotación
│   │   └── settings_screen.dart    # Configuración de temas institucionales
│   └── widgets/
│       ├── breadcrumb_bar.dart     # Barra de navegación jerárquica
│       ├── create_item_dialog.dart # Diálogo para crear carpetas y archivos
│       └── file_list_tile.dart     # Tarjeta con íconos por tipo, favoritos y opciones
└── main.dart                       # Configuración de MultiProvider y runApp
```

---

## 📦 Plugins y Dependencias Utilizadas

| Dependencia | Versión | Justificación técnica |
|---|---|---|
| `provider` | `^6.1.2` | Gestor de estado reactivo recomendado oficialmente por Google para Flutter, permitiendo separar la lógica de negocio de la interfaz sin sobrecoste de memoria. |
| `path_provider` | `^2.1.2` | Plugin multiplataforma estándar para obtener las rutas absolutas seguras del sandbox local en Android (`context.getFilesDir()`) e iOS (`NSDocumentDirectory`). |
| `shared_preferences` | `^2.2.2` | Almacenamiento local persistente tipo clave-valor para guardar el historial de archivos favoritos y el tema institucional seleccionado. |
| `intl` | `^0.19.0` | Formateo estandarizado de fechas y horas de modificación de los archivos. |
| `cupertino_icons` | `^1.0.8` | Compatibilidad y coherencia visual con la iconografía nativa del sistema operativo iOS. |

---

## ✨ Funcionalidades Principales

1. **Exploración Jerárquica:**
   - Navegación fluida por carpetas con una barra interactiva de *Breadcrumbs* (migas de pan) que permite saltar a cualquier nivel superior con un solo toque.
2. **Íconos Representativos:**
   - Distinción visual inmediata entre carpetas, imágenes, archivos de texto, código/JSON y archivos genéricos.
3. **Visor y Editor de Texto:**
   - Permite abrir archivos `.txt`, `.md`, `.json`, editarlos con fuente monoespaciada y guardar las modificaciones directamente en disco.
4. **Visor de Imágenes:**
   - Implementa `InteractiveViewer` para soporte de gestos de pinza (*pinch-to-zoom* hasta 5x), doble toque y botón de rotación a 90°.
5. **Gestión de Archivos (CRUD):**
   - Crear carpetas y archivos de texto con contenido inicial.
   - Renombrar elementos existentes.
   - Eliminar carpetas y archivos con diálogo de confirmación de seguridad.
6. **Búsqueda y Ordenamiento:**
   - Filtro de búsqueda en tiempo real dentro del directorio actual.
   - Criterios de ordenamiento ascendente y descendente por: **Nombre**, **Fecha de modificación** y **Tamaño**.
7. **Favoritos:**
   - Marcado de elementos favoritos con estrellas doradas y persistencia entre reinicios de la aplicación.
