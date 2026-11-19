import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

/// Crea, sólo la primera vez, archivos de ejemplo en el almacenamiento propio de la app
/// para poder demostrar todos los visores sin conexión a Internet.
class SampleFiles {
  static Future<void> ensure(Directory root) async {
    final marker = File(p.join(root.path, '.ejemplos_creados'));
    if (await marker.exists()) return;
    try {
      await _write(root, 'Bienvenida.txt', _txt);
      await _write(root, 'Notas.md', _md);
      final docs = Directory(p.join(root.path, 'Documentos'));
      await docs.create(recursive: true);
      await _write(docs, 'configuracion.json', _json);
      await _write(docs, 'catalogo.xml', _xml);
      await _write(docs, 'datos.csv', 'materia,creditos\nMoviles,7.5\nRedes,7.5\n');
      final imgs = Directory(p.join(root.path, 'Imagenes'));
      await imgs.create(recursive: true);
      await File(p.join(imgs.path, 'degradado_ipn.png')).writeAsBytes(await _image(const Color(0xFF6C1D45)));
      await File(p.join(imgs.path, 'degradado_escom.png')).writeAsBytes(await _image(const Color(0xFF003366)));
      await marker.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {
      // Sin ejemplos no pasa nada: la app sigue funcionando.
    }
  }

  static Future<void> _write(Directory d, String name, String content) =>
      File(p.join(d.path, name)).writeAsString(content);

  /// Genera una imagen PNG con el lienzo de Flutter (no requiere assets ni red).
  static Future<List<int>> _image(Color base) async {
    const w = 800, h = 600;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rect = const Rect.fromLTWH(0, 0, 800, 600);
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(800, 600), [base, const Color(0xFFD4AF37)]),
    );
    final paint = Paint()..color = const Color(0x55FFFFFF);
    for (var i = 0; i < 12; i++) {
      c.drawCircle(Offset(80.0 + i * 60, 300 + 180 * math.sin(i / 2)), 30.0 + i * 3, paint);
    }
    final tp = TextPainter(
      text: const TextSpan(
          text: 'ESCOM · IPN', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 72, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((w - tp.width) / 2, (h - tp.height) / 2));
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static const _txt = '''Gestor de Archivos Multiplataforma
==================================

Práctica 4 — Desarrollo de Aplicaciones Móviles Nativas (ESCOM-IPN)

Esta carpeta es el almacenamiento privado de la aplicación.
Desde aquí puedes:
  * Crear carpetas y archivos de texto.
  * Copiar, mover, renombrar y eliminar.
  * Ver metadatos (tamaño, fechas y tipo MIME/UTType).
  * Marcar favoritos y consultar recientes.

Para trabajar con otras carpetas usa "Autorizar carpeta": el sistema
te mostrará su selector y la app sólo verá lo que tú elijas.
''';

  static const _md = '''# Notas de la práctica

## Objetivos
- Explorar el **almacenamiento propio** de la app.
- Abrir carpetas elegidas con el *selector del sistema*.
- Visualizar `TXT`, `MD`, `JSON`, `XML` e imágenes.

## Seguridad
1. Android: Storage Access Framework (SAF).
2. iOS: sandbox + UIDocumentPicker + bookmarks.

> Ningún permiso de almacenamiento global es necesario.
''';

  static const _json = '''{"app":"Gestor de Archivos","version":"1.0.0","offline":true,"temas":["guinda","azul"],"plataformas":{"android":{"minSdk":24,"api":"Storage Access Framework"},"ios":{"minimo":"15.0","api":"UIDocumentPickerViewController"}},"limites":{"recientes":30,"miniaturasMemoria":120},"autor":null}''';

  static const _xml = '''<?xml version="1.0" encoding="UTF-8"?>
<!-- Catálogo de unidades de aprendizaje -->
<catalogo escuela="ESCOM" plan="2020">
  <materia clave="DAMN" semestre="7"><nombre>Desarrollo de Aplicaciones Móviles Nativas</nombre><creditos>7.5</creditos></materia>
  <materia clave="RC" semestre="5"><nombre>Redes de Computadoras</nombre><creditos>7.5</creditos></materia>
  <materia clave="IA" semestre="6"><nombre>Inteligencia Artificial</nombre><creditos>7.5</creditos></materia>
</catalogo>
''';
}
