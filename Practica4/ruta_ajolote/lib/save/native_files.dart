import 'dart:io';

import 'package:flutter/services.dart';

/// Puente al código nativo para EXPORTAR una partida a una ubicación elegida por el
/// usuario e IMPORTAR una partida desde el selector del sistema.
/// Android: ACTION_CREATE_DOCUMENT / ACTION_OPEN_DOCUMENT (SAF, sin permisos).
/// iOS: UIDocumentPickerViewController (exportar copia / abrir copia).
class NativeFiles {
  static const _ch = MethodChannel('mx.ipn.escom/archivos');

  /// Devuelve true si se exportó, false si el usuario canceló.
  static Future<bool> export(String path, String name, String mime) async {
    final r = await _ch.invokeMethod<String>('exportFile', {'path': path, 'name': name, 'mime': mime});
    return r != null;
  }

  /// Devuelve (nombre, bytes) o null si el usuario canceló.
  static Future<(String, Uint8List)?> pickFile() async {
    final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('pickFile');
    if (r == null) return null;
    final name = r['name'] as String;
    if (r['bytes'] != null) return (name, r['bytes'] as Uint8List);
    // iOS entrega una copia temporal en el sandbox.
    final f = File(r['path'] as String);
    final bytes = await f.readAsBytes();
    try {
      await f.delete();
    } catch (_) {}
    return (name, bytes);
  }
}
