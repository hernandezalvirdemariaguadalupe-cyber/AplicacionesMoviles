import 'dart:io';

import 'package:flutter/services.dart';

import '../core/errors.dart';
import 'models.dart';

/// Puente hacia el código específico de cada plataforma
/// (MainActivity.kt en Android, StoragePlugin en AppDelegate.swift en iOS).
class NativeStorage {
  static const _ch = MethodChannel('mx.ipn.escom/storage');

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args, String action = 'completar la operación']) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } catch (e) {
      throw FsException.from(e, action: action);
    }
  }

  /// Abre el selector de carpetas del sistema. Devuelve null si el usuario cancela.
  static Future<Map<dynamic, dynamic>?> pickDirectory() =>
      _call<Map<dynamic, dynamic>>('pickDirectory', null, 'abrir la carpeta');

  /// Abre el selector de archivos del sistema (selección múltiple).
  static Future<List<Map<dynamic, dynamic>>> pickFiles() async {
    final r = await _call<List<dynamic>>('pickFiles', null, 'abrir los archivos');
    return r?.cast<Map<dynamic, dynamic>>() ?? const [];
  }

  /// iOS: recupera el acceso a una ubicación a partir de su bookmark.
  static Future<Map<dynamic, dynamic>?> resolveBookmark(String bookmark) =>
      _call<Map<dynamic, dynamic>>('resolveBookmark', {'bookmark': bookmark}, 'recuperar el acceso');

  /// Android: URIs de árbol cuyo permiso persistente sigue vigente.
  static Future<List<String>> persistedRoots() async =>
      (await _call<List<dynamic>>('persistedRoots'))?.cast<String>() ?? const [];

  static Future<void> release(String uri) => _call('release', {'uri': uri});

  static Future<int?> freeSpace(String path) async => (await _call<num>('freeSpace', {'path': path}))?.toInt();

  /// Fecha de creación y tipo (MIME en Android, UTType en iOS) de un archivo local.
  static Future<Map<dynamic, dynamic>?> localAttributes(String path) =>
      _call<Map<dynamic, dynamic>>('localAttributes', {'path': path}, 'leer los metadatos');

  static Future<bool> openWith(String ref, String? mime) async =>
      (await _call<bool>('openWith', {'ref': ref, 'mime': mime}, 'abrir con otra aplicación')) ?? false;

  /// Guarda una copia en una ubicación elegida por el usuario. Null si cancela.
  static Future<String?> exportFile(String ref, String name, String? mime) =>
      _call<String>('exportFile', {'ref': ref, 'name': name, 'mime': mime}, 'exportar el archivo');

  // ---- SAF (sólo Android) ----

  static Future<List<FsEntry>> safList(String uri) async {
    final r = await _call<List<dynamic>>('list', {'uri': uri}, 'leer la carpeta');
    return (r ?? const []).map((m) => FsEntry.fromMap(m as Map)).toList();
  }

  static Future<FsEntry> safStat(String uri) async =>
      FsEntry.fromMap((await _call<Map<dynamic, dynamic>>('stat', {'uri': uri}, 'leer el archivo'))!);

  static Future<Uint8List> safRead(String uri, {int? maxBytes}) async =>
      (await _call<Uint8List>('read', {'uri': uri, 'maxBytes': maxBytes}, 'leer el archivo'))!;

  static Future<void> safWrite(String uri, Uint8List bytes) =>
      _call('write', {'uri': uri, 'bytes': bytes}, 'guardar el archivo');

  static Future<String> safCreateFile(String parent, String name, Uint8List bytes, String? mime) async =>
      (await _call<String>('createFile', {'parent': parent, 'name': name, 'bytes': bytes, 'mime': mime},
          'crear el archivo'))!;

  static Future<String> safCreateDirectory(String parent, String name) async =>
      (await _call<String>('createDirectory', {'parent': parent, 'name': name}, 'crear la carpeta'))!;

  static Future<void> safDelete(String uri) => _call('delete', {'uri': uri}, 'eliminar');

  static Future<String> safRename(String uri, String name) async =>
      (await _call<String>('rename', {'uri': uri, 'name': name}, 'renombrar'))!;

  static bool get isAndroid => Platform.isAndroid;
}
