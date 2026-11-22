import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';
import 'models.dart';
import 'storage_service.dart';

/// Caché de miniaturas en dos niveles:
///  1. Memoria (LRU de [_maxMemory] elementos) → desplazamiento fluido en listas.
///  2. Disco (carpeta de caché del SO) → no se vuelven a decodificar imágenes
///     grandes entre sesiones. La clave incluye ruta + fecha + tamaño, así una imagen
///     modificada genera una miniatura nueva automáticamente.
class ThumbnailCache {
  ThumbnailCache(this._storage);

  final StorageService _storage;
  static const _maxMemory = 120;
  static const _thumbWidth = 160;
  static const _maxSourceBytes = 25 * 1024 * 1024;

  final _memory = <String, Uint8List>{}; // LinkedHashMap: conserva orden de uso (LRU)
  final _inFlight = <String, Future<Uint8List?>>{};
  Directory? _dir;

  int hits = 0;
  int misses = 0;

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final tmp = await getTemporaryDirectory();
    _dir = Directory(p.join(tmp.path, 'miniaturas'));
    await _dir!.create(recursive: true);
    return _dir!;
  }

  String _key(FsEntry e) => fnv1a('${e.ref}|${e.modified?.millisecondsSinceEpoch}|${e.size}');

  Uint8List? peek(FsEntry e) {
    final k = _key(e);
    final v = _memory.remove(k);
    if (v != null) _memory[k] = v; // marca como usado recientemente
    return v;
  }

  Future<Uint8List?> get(FsEntry e) {
    final k = _key(e);
    final mem = peek(e);
    if (mem != null) {
      hits++;
      return Future.value(mem);
    }
    // Ojo: el callback NO debe devolver el Future removido; whenComplete esperaría
    // a ese mismo Future y la carga nunca terminaría (bloqueo circular).
    return _inFlight.putIfAbsent(k, () => _load(e, k).whenComplete(() {
          _inFlight.remove(k);
        }));
  }

  Future<Uint8List?> _load(FsEntry e, String k) async {
    try {
      final file = File(p.join((await _cacheDir()).path, '$k.png'));
      if (await file.exists()) {
        hits++;
        return _remember(k, await file.readAsBytes());
      }
      misses++;
      if ((e.size ?? 0) > _maxSourceBytes) return null;
      final source = await _storage.read(e.ref);
      final codec = await ui.instantiateImageCodec(source, targetWidth: _thumbWidth);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return null;
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes);
      return _remember(k, bytes);
    } catch (err) {
      debugPrint('Miniatura no disponible para ${e.name}: $err');
      return null; // imagen corrupta o ilegible → se muestra el icono genérico
    }
  }

  Uint8List _remember(String k, Uint8List v) {
    _memory[k] = v;
    while (_memory.length > _maxMemory) {
      _memory.remove(_memory.keys.first);
    }
    return v;
  }

  Future<(int files, int bytes)> diskUsage() async {
    final dir = await _cacheDir();
    var files = 0, bytes = 0;
    await for (final f in dir.list()) {
      if (f is File) {
        files++;
        bytes += await f.length();
      }
    }
    return (files, bytes);
  }

  Future<void> clear() async {
    _memory.clear();
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    _dir = null;
    hits = 0;
    misses = 0;
  }
}
