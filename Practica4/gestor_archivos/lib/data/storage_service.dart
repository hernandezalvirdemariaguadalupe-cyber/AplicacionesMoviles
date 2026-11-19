import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/errors.dart';
import 'models.dart';
import 'native_storage.dart';

/// Operaciones de archivos unificadas.
///
/// - Referencias con `content://` (Android/SAF) → se delegan a [NativeStorage].
/// - Rutas normales (almacenamiento propio en ambos SO y carpetas autorizadas en iOS,
///   ya abiertas con su recurso security-scoped) → `dart:io`.
///
/// Todas las operaciones lanzan [FsException] con mensajes legibles.
class StorageService {
  /// Directorio privado de la app.
  /// Android: filesDir (cubierto por el FileProvider). iOS: Documents (visible en Archivos).
  static Future<Directory> appStorageDir() async {
    final base = Platform.isIOS ? await getApplicationDocumentsDirectory() : await getApplicationSupportDirectory();
    final dir = Platform.isIOS ? base : Directory(p.join(base.path, 'MisArchivos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ------------------------------------------------------------------ lectura

  Future<List<FsEntry>> list(String dirRef) async {
    try {
      final List<FsEntry> items;
      if (_isSaf(dirRef)) {
        items = await NativeStorage.safList(dirRef);
      } else {
        final dir = Directory(dirRef);
        if (!await dir.exists()) {
          throw const FsException(FsErrorKind.notFound, 'La carpeta ya no existe o no está disponible.');
        }
        items = [];
        await for (final e in dir.list(followLinks: false)) {
          final name = p.basename(e.path);
          if (name.startsWith('.')) continue; // archivos ocultos del sistema
          try {
            final st = await e.stat();
            items.add(FsEntry(
              ref: e.path,
              name: name,
              isDir: st.type == FileSystemEntityType.directory,
              size: st.type == FileSystemEntityType.directory ? null : st.size,
              modified: st.modified,
            ));
          } catch (_) {
            // Un elemento ilegible no impide mostrar el resto.
          }
        }
      }
      items.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return items;
    } catch (e) {
      throw FsException.from(e, action: 'leer la carpeta');
    }
  }

  /// Metadatos completos (incluye fecha de creación y UTType/MIME cuando existen).
  Future<FsEntry> stat(String ref) async {
    try {
      if (_isSaf(ref)) return await NativeStorage.safStat(ref);
      final type = await FileSystemEntity.type(ref);
      if (type == FileSystemEntityType.notFound) {
        throw const FsException(FsErrorKind.notFound, 'El archivo ya no existe.');
      }
      final st = await FileStat.stat(ref);
      var entry = FsEntry(
        ref: ref,
        name: p.basename(ref),
        isDir: type == FileSystemEntityType.directory,
        size: type == FileSystemEntityType.directory ? null : st.size,
        modified: st.modified,
      );
      try {
        final attrs = await NativeStorage.localAttributes(ref);
        if (attrs != null) {
          final c = attrs['created'];
          entry = entry.copyWith(
            created: c == null ? null : DateTime.fromMillisecondsSinceEpoch((c as num).toInt()),
            utType: Platform.isIOS ? attrs['type'] as String? : null,
            mime: (attrs['mime'] ?? (Platform.isAndroid ? attrs['type'] : null)) as String?,
          );
        }
      } catch (_) {
        // Los metadatos extra son opcionales: se mostrarán como "No disponible".
      }
      return entry;
    } catch (e) {
      throw FsException.from(e, action: 'leer los metadatos');
    }
  }

  Future<Uint8List> read(String ref, {int? maxBytes}) async {
    try {
      if (_isSaf(ref)) return await NativeStorage.safRead(ref, maxBytes: maxBytes);
      final f = File(ref);
      if (!await f.exists()) throw const FsException(FsErrorKind.notFound, 'El archivo ya no existe.');
      if (maxBytes == null) return await f.readAsBytes();
      final raf = await f.open();
      try {
        return await raf.read(maxBytes);
      } finally {
        await raf.close();
      }
    } catch (e) {
      final ex = FsException.from(e, action: 'leer el archivo');
      if (ex.kind == FsErrorKind.unknown) {
        throw FsException(FsErrorKind.readFailed, 'La lectura del archivo falló.', ex.detail);
      }
      throw ex;
    }
  }

  // ------------------------------------------------------------------ escritura

  Future<void> overwrite(FsEntry file, Uint8List bytes) async {
    if (!file.canWrite) {
      throw const FsException(FsErrorKind.permissionDenied, 'Este archivo es de sólo lectura en su proveedor.');
    }
    await _ensureSpace(p.dirname(file.ref), bytes.length - (file.size ?? 0));
    try {
      if (file.isSaf) {
        await NativeStorage.safWrite(file.ref, bytes);
      } else {
        // Escritura atómica: primero a un temporal y luego se reemplaza.
        final tmp = File('${file.ref}.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(file.ref);
      }
    } catch (e) {
      throw FsException.from(e, action: 'guardar el archivo');
    }
  }

  Future<String> createFile(FsEntry dir, String name, Uint8List bytes, {String? mime}) async {
    await _validateDestination(dir, name, bytes.length);
    try {
      if (dir.isSaf) return await NativeStorage.safCreateFile(dir.ref, name, bytes, mime);
      final f = File(p.join(dir.ref, name));
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } catch (e) {
      throw FsException.from(e, action: 'crear el archivo');
    }
  }

  Future<String> createDirectory(FsEntry dir, String name) async {
    await _validateDestination(dir, name, 0);
    try {
      if (dir.isSaf) return await NativeStorage.safCreateDirectory(dir.ref, name);
      final d = Directory(p.join(dir.ref, name));
      await d.create();
      return d.path;
    } catch (e) {
      throw FsException.from(e, action: 'crear la carpeta');
    }
  }

  Future<void> delete(FsEntry e) async {
    if (!e.canDelete) {
      throw const FsException(FsErrorKind.permissionDenied, 'El proveedor de documentos no permite eliminar este elemento.');
    }
    try {
      if (e.isSaf) {
        await NativeStorage.safDelete(e.ref);
      } else if (e.isDir) {
        await Directory(e.ref).delete(recursive: true);
      } else {
        await File(e.ref).delete();
      }
    } catch (err) {
      throw FsException.from(err, action: 'eliminar');
    }
  }

  Future<String> rename(FsEntry e, String newName, {required String parentRef}) async {
    if (!e.canRename) {
      throw const FsException(FsErrorKind.permissionDenied, 'El proveedor de documentos no permite renombrar este elemento.');
    }
    if (newName == e.name) return e.ref;
    final siblings = await list(parentRef);
    if (siblings.any((s) => s.name.toLowerCase() == newName.toLowerCase() && s.ref != e.ref)) {
      throw const FsException(FsErrorKind.alreadyExists, 'Ya existe un elemento con ese nombre.');
    }
    try {
      if (e.isSaf) return await NativeStorage.safRename(e.ref, newName);
      final target = p.join(p.dirname(e.ref), newName);
      final renamed = e.isDir ? await Directory(e.ref).rename(target) : await File(e.ref).rename(target);
      return renamed.path;
    } catch (err) {
      throw FsException.from(err, action: 'renombrar');
    }
  }

  /// Copia (o mueve) [src] dentro de [destDir]. Funciona entre cualquier combinación de
  /// almacenamiento propio, SAF y carpetas de iOS. Si el nombre ya existe se agrega " (n)".
  Future<String> copy(FsEntry src, FsEntry destDir, {bool move = false}) async {
    if (!src.isSaf && !destDir.isSaf && src.isDir && p.isWithin(src.ref, destDir.ref) || src.ref == destDir.ref) {
      throw const FsException(FsErrorKind.unsupported, 'No se puede copiar una carpeta dentro de sí misma.');
    }
    final existing = (await list(destDir.ref)).map((e) => e.name.toLowerCase()).toSet();
    final name = _uniqueName(src.name, existing);

    // Movimiento rápido dentro del mismo sistema de archivos local.
    if (move && !src.isSaf && !destDir.isSaf) {
      try {
        final target = p.join(destDir.ref, name);
        final moved = src.isDir ? await Directory(src.ref).rename(target) : await File(src.ref).rename(target);
        return moved.path;
      } catch (_) {
        // Volúmenes distintos: se cae al copiar + eliminar.
      }
    }

    final String created;
    if (src.isDir) {
      final newDir = await createDirectory(destDir, name);
      final newDirEntry = await stat(newDir);
      for (final child in await list(src.ref)) {
        await copy(child, newDirEntry);
      }
      created = newDir;
    } else {
      final bytes = await read(src.ref);
      created = await createFile(destDir, name, bytes, mime: src.effectiveMime);
    }
    if (move) await delete(src);
    return created;
  }

  /// Archivo local equivalente (para compartir). SAF se copia a caché temporal.
  Future<String> asLocalFile(FsEntry e) async {
    if (!e.isSaf) return e.ref;
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'compartir'));
    await dir.create(recursive: true);
    final f = File(p.join(dir.path, e.name));
    await f.writeAsBytes(await read(e.ref));
    return f.path;
  }

  // ------------------------------------------------------------------ validaciones

  /// Antes de escribir: el destino debe admitir creación, el nombre no debe existir
  /// y debe haber espacio libre suficiente.
  Future<void> _validateDestination(FsEntry dir, String name, int bytes) async {
    if (!dir.isDir) {
      throw const FsException(FsErrorKind.unsupported, 'El destino no es una carpeta.');
    }
    if (!dir.canCreate) {
      throw const FsException(FsErrorKind.permissionDenied, 'Esta carpeta no admite crear elementos (sólo lectura).');
    }
    final siblings = await list(dir.ref);
    if (siblings.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      throw const FsException(FsErrorKind.alreadyExists, 'Ya existe un elemento con ese nombre en el destino.');
    }
    if (!dir.isSaf) await _ensureSpace(dir.ref, bytes);
  }

  Future<void> _ensureSpace(String path, int bytes) async {
    if (bytes <= 0 || path.startsWith('content://')) return;
    try {
      final free = await NativeStorage.freeSpace(path);
      if (free != null && free < bytes + 1024 * 1024) {
        throw const FsException(FsErrorKind.noSpace, 'No hay espacio suficiente en el almacenamiento.');
      }
    } on FsException catch (e) {
      if (e.kind == FsErrorKind.noSpace) rethrow;
    }
  }

  static String _uniqueName(String name, Set<String> existing) {
    if (!existing.contains(name.toLowerCase())) return name;
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    for (var i = 1;; i++) {
      final candidate = '$base ($i)$ext';
      if (!existing.contains(candidate.toLowerCase())) return candidate;
    }
  }

  static bool _isSaf(String ref) => ref.startsWith('content://');
}
