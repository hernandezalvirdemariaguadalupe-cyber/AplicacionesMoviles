import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../game/model.dart';
import 'codec.dart';

/// Una partida guardada en disco. Si el archivo está dañado, [state] es null y
/// [error] explica el problema; las demás partidas se siguen mostrando.
class SaveEntry {
  final File file;
  final SaveFormat format;
  final int size;
  final DateTime modified;
  final GameState? state;
  final String? error;

  const SaveEntry({
    required this.file,
    required this.format,
    required this.size,
    required this.modified,
    this.state,
    this.error,
  });

  String get fileName => p.basename(file.path);
  bool get isValid => state != null;
}

/// Error de E/S con mensaje legible.
class SaveIoException implements Exception {
  final String message;
  const SaveIoException(this.message);
  @override
  String toString() => message;
}

/// Gestión de partidas en el almacenamiento PRIVADO de la app
/// (Android: `/data/data/PAQUETE/files/partidas` · iOS: `Library/Application Support/partidas`).
class SaveRepository {
  static const autosaveName = 'autoguardado';
  Directory? _dir;

  Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    _dir = Directory(p.join(base.path, 'partidas'));
    await _dir!.create(recursive: true);
    return _dir!;
  }

  // ------------------------------------------------------------------ lectura

  Future<List<SaveEntry>> list() async {
    final d = await dir();
    final out = <SaveEntry>[];
    await for (final f in d.list()) {
      if (f is! File) continue;
      final name = p.basenameWithoutExtension(f.path);
      final format = SaveFormat.fromExtension(p.extension(f.path));
      if (format == null || name == autosaveName) continue;
      out.add(await _read(f, format));
    }
    out.sort((a, b) {
      final ta = a.state?.updatedAt ?? a.modified;
      final tb = b.state?.updatedAt ?? b.modified;
      return tb.compareTo(ta);
    });
    return out;
  }

  Future<SaveEntry> _read(File f, SaveFormat format) async {
    final stat = await f.stat();
    try {
      final text = await f.readAsString();
      return SaveEntry(
        file: f,
        format: format,
        size: stat.size,
        modified: stat.modified,
        state: SaveCodec.decode(text, format),
      );
    } on SaveFormatException catch (e) {
      return SaveEntry(file: f, format: format, size: stat.size, modified: stat.modified, error: e.message);
    } on FormatException {
      return SaveEntry(
          file: f, format: format, size: stat.size, modified: stat.modified, error: 'El archivo no es texto UTF-8 válido.');
    } on FileSystemException catch (e) {
      return SaveEntry(
          file: f, format: format, size: stat.size, modified: stat.modified, error: 'No se pudo leer: ${e.message}');
    }
  }

  Future<String> readRaw(SaveEntry e) async {
    try {
      return await e.file.readAsString();
    } on FormatException {
      return utf8.decode(await e.file.readAsBytes(), allowMalformed: true);
    }
  }

  // ------------------------------------------------------------------ escritura

  /// Guarda la partida en [format]. Si ya existía un archivo de la misma partida en
  /// ese formato se sobrescribe; la escritura es atómica (temporal + renombrar).
  Future<File> save(GameState s, SaveFormat format) async {
    final d = await dir();
    s.updatedAt = DateTime.now();
    final file = File(p.join(d.path, '${_safe(s.id)}.${format.ext}'));
    await _atomicWrite(file, SaveCodec.encode(s, format));
    return file;
  }

  Future<void> delete(SaveEntry e) async {
    try {
      if (await e.file.exists()) await e.file.delete();
    } on FileSystemException catch (err) {
      throw SaveIoException('No se pudo eliminar la partida: ${err.message}');
    }
  }

  /// Cambia nombre y etiquetas reescribiendo el archivo en su mismo formato.
  Future<void> updateInfo(SaveEntry e, {required String name, required List<String> tags}) async {
    final s = e.state;
    if (s == null) throw const SaveIoException('No se puede editar una partida dañada.');
    s
      ..name = name
      ..tags = tags;
    await _atomicWrite(e.file, SaveCodec.encode(s, e.format));
  }

  /// Crea una copia de la partida en otro formato.
  Future<File> convert(SaveEntry e, SaveFormat to) async {
    final s = e.state;
    if (s == null) throw const SaveIoException('No se puede convertir una partida dañada.');
    return save(s, to);
  }

  /// Importa un archivo externo (elegido con el selector del sistema).
  /// Se valida completo ANTES de copiarlo; se le asigna un id nuevo.
  Future<GameState> import(String fileName, Uint8List bytes) async {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const SaveFormatException('El archivo no es texto UTF-8 válido.');
    }
    final format = SaveFormat.fromExtension(p.extension(fileName)) ?? SaveFormat.sniff(text);
    final s = SaveCodec.decode(text, format);
    s.id = 'p${DateTime.now().microsecondsSinceEpoch}';
    await save(s, format);
    return s;
  }

  // ------------------------------------------------------------------ autoguardado

  Future<void> autosave(GameState s, SaveFormat format) async {
    final d = await dir();
    for (final f in SaveFormat.values) {
      if (f == format) continue;
      final old = File(p.join(d.path, '$autosaveName.${f.ext}'));
      if (await old.exists()) await old.delete();
    }
    await _atomicWrite(File(p.join(d.path, '$autosaveName.${format.ext}')), SaveCodec.encode(s, format));
  }

  /// Devuelve la partida autoguardada (si existe y es válida) o el motivo del error.
  Future<(GameState?, String?)> loadAutosave() async {
    final d = await dir();
    for (final f in SaveFormat.values) {
      final file = File(p.join(d.path, '$autosaveName.${f.ext}'));
      if (await file.exists()) {
        final e = await _read(file, f);
        return (e.state, e.error);
      }
    }
    return (null, null);
  }

  Future<void> clearAutosave() async {
    final d = await dir();
    for (final f in SaveFormat.values) {
      final file = File(p.join(d.path, '$autosaveName.${f.ext}'));
      if (await file.exists()) await file.delete();
    }
  }

  // ------------------------------------------------------------------ utilidades

  Future<void> _atomicWrite(File target, String content) async {
    final tmp = File('${target.path}.tmp');
    try {
      await tmp.writeAsString(content, flush: true);
      await tmp.rename(target.path);
    } on FileSystemException catch (e) {
      if (await tmp.exists()) await tmp.delete();
      final noSpace = e.osError?.errorCode == 28;
      throw SaveIoException(noSpace
          ? 'No hay espacio suficiente para guardar la partida.'
          : 'No se pudo guardar la partida: ${e.osError?.message ?? e.message}');
    }
  }

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
