import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// Categoría de visor que corresponde a un archivo.
enum ViewerKind { text, markdown, json, xml, image, unsupported }

/// Un archivo o carpeta. [ref] es una ruta del sistema de archivos (almacenamiento
/// propio o carpeta autorizada en iOS) o una URI `content://` de SAF en Android.
class FsEntry {
  final String ref;
  final String name;
  final bool isDir;
  final int? size;
  final DateTime? modified;
  final DateTime? created;
  final String? mime;
  final String? utType; // Sólo iOS (Uniform Type Identifier)
  final bool canWrite;
  final bool canDelete;
  final bool canRename;
  final bool canCreate;

  const FsEntry({
    required this.ref,
    required this.name,
    required this.isDir,
    this.size,
    this.modified,
    this.created,
    this.mime,
    this.utType,
    this.canWrite = true,
    this.canDelete = true,
    this.canRename = true,
    this.canCreate = true,
  });

  bool get isSaf => ref.startsWith('content://');

  String get extension => p.extension(name).toLowerCase().replaceFirst('.', '');

  /// MIME informado por la plataforma o deducido por la extensión.
  String? get effectiveMime {
    if (isDir) return null;
    if (mime != null && mime != 'application/octet-stream') return mime;
    return _extraMime[extension] ?? lookupMimeType(name) ?? mime;
  }

  ViewerKind get viewer {
    if (isDir) return ViewerKind.unsupported;
    switch (extension) {
      case 'json':
      case 'geojson':
        return ViewerKind.json;
      case 'xml':
      case 'svg':
      case 'plist':
      case 'xsd':
        return ViewerKind.xml;
      case 'md':
      case 'markdown':
        return ViewerKind.markdown;
      case 'txt':
      case 'log':
      case 'ini':
      case 'cfg':
      case 'yaml':
      case 'yml':
      case 'dart':
      case 'kt':
      case 'swift':
      case 'java':
      case 'c':
      case 'h':
      case 'py':
      case 'js':
      case 'html':
      case 'css':
        return ViewerKind.text;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'bmp':
        return ViewerKind.image;
    }
    final m = effectiveMime ?? '';
    if (m.startsWith('image/') && !m.contains('svg') && !m.contains('heic')) return ViewerKind.image;
    if (m.contains('json')) return ViewerKind.json;
    if (m.contains('xml')) return ViewerKind.xml;
    if (m.startsWith('text/')) return ViewerKind.text;
    return ViewerKind.unsupported;
  }

  FsEntry copyWith({DateTime? created, String? utType, String? mime, int? size, DateTime? modified}) =>
      FsEntry(
        ref: ref,
        name: name,
        isDir: isDir,
        size: size ?? this.size,
        modified: modified ?? this.modified,
        created: created ?? this.created,
        mime: mime ?? this.mime,
        utType: utType ?? this.utType,
        canWrite: canWrite,
        canDelete: canDelete,
        canRename: canRename,
        canCreate: canCreate,
      );

  /// Construye desde el mapa que devuelve el canal nativo.
  factory FsEntry.fromMap(Map<dynamic, dynamic> m) {
    DateTime? ms(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
    return FsEntry(
      ref: m['ref'] as String,
      name: (m['name'] as String?) ?? 'sin_nombre',
      isDir: (m['isDir'] as bool?) ?? false,
      size: (m['size'] as num?)?.toInt(),
      modified: ms(m['modified']),
      mime: m['mime'] as String?,
      canWrite: (m['canWrite'] as bool?) ?? true,
      canDelete: (m['canDelete'] as bool?) ?? true,
      canRename: (m['canRename'] as bool?) ?? true,
      canCreate: (m['canCreate'] as bool?) ?? true,
    );
  }

  static const _extraMime = {
    'md': 'text/markdown',
    'markdown': 'text/markdown',
    'json': 'application/json',
    'xml': 'application/xml',
    'yaml': 'application/yaml',
    'yml': 'application/yaml',
    'dart': 'text/x-dart',
    'kt': 'text/x-kotlin',
    'swift': 'text/x-swift',
  };
}

/// Una ubicación raíz que el usuario puede explorar.
enum LocationKind { appStorage, folder, file }

class StorageLocation {
  final String id;
  final LocationKind kind;
  final String name;
  final String ref; // ruta o URI de documento raíz
  final String? bookmark; // iOS: bookmark security-scoped en base64
  final String? treeUri; // Android: URI del árbol (para liberar el permiso)
  final DateTime addedAt;
  bool available;

  StorageLocation({
    required this.id,
    required this.kind,
    required this.name,
    required this.ref,
    this.bookmark,
    this.treeUri,
    DateTime? addedAt,
    this.available = true,
  }) : addedAt = addedAt ?? DateTime.now();

  StorageLocation copyWith({String? ref, String? bookmark, bool? available}) => StorageLocation(
        id: id,
        kind: kind,
        name: name,
        ref: ref ?? this.ref,
        bookmark: bookmark ?? this.bookmark,
        treeUri: treeUri,
        addedAt: addedAt,
        available: available ?? this.available,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'ref': ref,
        'bookmark': bookmark,
        'treeUri': treeUri,
        'addedAt': addedAt.toIso8601String(),
      };

  factory StorageLocation.fromJson(Map<String, dynamic> j) => StorageLocation(
        id: j['id'] as String,
        kind: LocationKind.values.byName(j['kind'] as String),
        name: j['name'] as String,
        ref: j['ref'] as String,
        bookmark: j['bookmark'] as String?,
        treeUri: j['treeUri'] as String?,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? ''),
      );
}

/// Elemento de "Recientes" o "Favoritos" (persistido en JSON).
class SavedRef {
  final String ref;
  final String name;
  final bool isDir;
  final String locationId;
  final DateTime at;

  SavedRef({required this.ref, required this.name, required this.isDir, required this.locationId, DateTime? at})
      : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() =>
      {'ref': ref, 'name': name, 'isDir': isDir, 'locationId': locationId, 'at': at.toIso8601String()};

  factory SavedRef.fromJson(Map<String, dynamic> j) => SavedRef(
        ref: j['ref'] as String,
        name: j['name'] as String,
        isDir: j['isDir'] as bool? ?? false,
        locationId: j['locationId'] as String? ?? 'app',
        at: DateTime.tryParse(j['at'] as String? ?? ''),
      );
}
