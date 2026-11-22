import 'dart:convert';

import 'package:xml/xml.dart';

import '../game/model.dart';

/// Formatos de guardado soportados.
enum SaveFormat {
  json('JSON', 'json', 'application/json'),
  xml('XML', 'xml', 'application/xml'),
  txt('Texto plano', 'txt', 'text/plain');

  const SaveFormat(this.label, this.ext, this.mime);
  final String label;
  final String ext;
  final String mime;

  static SaveFormat? fromExtension(String ext) {
    final e = ext.toLowerCase().replaceFirst('.', '');
    for (final f in values) {
      if (f.ext == e) return f;
    }
    return null;
  }

  /// Detecta el formato por el contenido (para archivos importados).
  static SaveFormat sniff(String content) {
    final t = content.trimLeft();
    if (t.startsWith('{')) return SaveFormat.json;
    if (t.startsWith('<')) return SaveFormat.xml;
    return SaveFormat.txt;
  }
}

/// Archivo vacío, incompleto o con datos inválidos. [message] es legible para el usuario.
class SaveFormatException implements Exception {
  final String message;
  const SaveFormatException(this.message);
  @override
  String toString() => message;
}

/// Serialización y deserialización de partidas en TXT, XML y JSON.
///
/// Los tres formatos se convierten a una estructura intermedia común
/// ([_RawSave]) y pasan por la MISMA validación en [_build], de modo que un archivo
/// dañado produce el mismo tipo de mensaje sin importar su formato.
class SaveCodec {
  static const magic = 'ruta-ajolote';
  static const version = 1;

  // ================================================================== codificar

  static String encode(GameState s, SaveFormat f) => switch (f) {
        SaveFormat.json => _toJson(s),
        SaveFormat.xml => _toXml(s),
        SaveFormat.txt => _toTxt(s),
      };

  static Map<String, String> _meta(GameState s) => {
        'id': s.id,
        'nombre': _clean(s.name),
        'modo': s.mode.name,
        'nivel': '${s.level}',
        'semilla': '${s.seed}',
        'estado': s.status.name,
        'creada': s.createdAt.toIso8601String(),
        'actualizada': s.updatedAt.toIso8601String(),
      };

  static Map<String, String> _player(GameState s) => {
        'posicion': '${s.player}',
        'inicio': '${s.start}',
        'vidas': '${s.lives}',
        'puntuacion': '${s.score}',
        'movimientos': '${s.moves}',
        'limiteMovimientos': '${s.moveLimit}',
        'burbujas': '${s.bubblesCollected}',
        'tiempoMs': '${s.elapsedMs}',
        'tiempoRestanteMs': '${s.timeLeftMs}',
      };

  static Map<String, String> _config(GameSettings c) => c.toJson().map((k, v) => MapEntry(k, '$v'));

  static String _clean(String v) => v.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  static List<String> _cleanTags(List<String> t) =>
      t.map((e) => _clean(e).replaceAll(',', ' ').replaceAll(';', ' ')).where((e) => e.isNotEmpty).toList();

  static String _toJson(GameState s) {
    final m = {
      'formato': magic,
      'version': version,
      'partida': {..._meta(s), 'etiquetas': _cleanTags(s.tags)},
      'jugador': {
        'posicion': '${s.player}',
        'inicio': '${s.start}',
        'vidas': s.lives,
        'puntuacion': s.score,
        'movimientos': s.moves,
        'limiteMovimientos': s.moveLimit,
        'burbujas': s.bubblesCollected,
        'tiempoMs': s.elapsedMs,
        'tiempoRestanteMs': s.timeLeftMs,
      },
      'mapa': s.gridRows,
      'configuracion': s.settings.toJson(),
      'historial': s.history.map((h) => h.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(m);
  }

  static String _toXml(GameState s) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8"');
    b.comment(' Ruta del Ajolote - partida guardada ');
    final meta = _meta(s);
    b.element('partida', nest: () {
      b.attribute('formato', magic);
      b.attribute('version', version);
      for (final k in ['id', 'modo', 'nivel', 'semilla', 'estado']) {
        b.attribute(k, meta[k]!);
      }
      b.element('nombre', nest: meta['nombre']);
      b.element('etiquetas', nest: () {
        for (final t in _cleanTags(s.tags)) {
          b.element('etiqueta', nest: t);
        }
      });
      b.element('fechas', nest: () {
        b.attribute('creada', meta['creada']!);
        b.attribute('actualizada', meta['actualizada']!);
      });
      b.element('jugador', nest: () => _player(s).forEach(b.attribute));
      b.element('mapa', nest: () {
        b.attribute('ancho', s.width);
        b.attribute('alto', s.height);
        for (final r in s.gridRows) {
          b.element('fila', nest: r);
        }
      });
      b.element('configuracion', nest: () => _config(s.settings).forEach(b.attribute));
      b.element('historial', nest: () {
        b.attribute('total', s.history.length);
        for (final h in s.history) {
          b.element('movimiento', nest: () => h.toJson().forEach((k, v) => b.attribute(k, '$v')));
        }
      });
    });
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  static String _toTxt(GameState s) {
    final sb = StringBuffer()
      ..writeln('# Ruta del Ajolote - partida guardada')
      ..writeln('# Formato INI: [SECCION] y clave=valor. No edites a mano.')
      ..writeln('FORMATO=$magic')
      ..writeln('VERSION=$version')
      ..writeln()
      ..writeln('[PARTIDA]');
    _meta(s).forEach((k, v) => sb.writeln('$k=$v'));
    sb
      ..writeln('etiquetas=${_cleanTags(s.tags).join(',')}')
      ..writeln()
      ..writeln('[JUGADOR]');
    _player(s).forEach((k, v) => sb.writeln('$k=$v'));
    sb
      ..writeln()
      ..writeln('[MAPA]');
    for (final r in s.gridRows) {
      sb.writeln(r);
    }
    sb
      ..writeln()
      ..writeln('[CONFIGURACION]');
    _config(s.settings).forEach((k, v) => sb.writeln('$k=$v'));
    sb
      ..writeln()
      ..writeln('[HISTORIAL]')
      ..writeln('# n;dir;desde;hasta;evento;ms');
    for (final h in s.history) {
      sb.writeln('${h.n};${h.dir.code};${h.from};${h.to};${h.event};${h.tMs}');
    }
    sb.writeln('[FIN]');
    return sb.toString();
  }

  // ================================================================== decodificar

  static GameState decode(String content, SaveFormat f) {
    if (content.trim().isEmpty) {
      throw const SaveFormatException('El archivo está vacío.');
    }
    final raw = switch (f) {
      SaveFormat.json => _fromJson(content),
      SaveFormat.xml => _fromXml(content),
      SaveFormat.txt => _fromTxt(content),
    };
    return _build(raw);
  }

  static _RawSave _fromJson(String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (e) {
      throw SaveFormatException('El JSON está incompleto o mal formado'
          '${e.offset != null ? ' (cerca del carácter ${e.offset})' : ''}.');
    }
    if (decoded is! Map) throw const SaveFormatException('El JSON no contiene un objeto de partida.');
    final Map root = decoded;
    Map<String, String> sec(String name) {
      final v = root[name];
      if (v is! Map) throw SaveFormatException('Falta la sección "$name".');
      return v.map((k, val) => MapEntry('$k', val == null ? '' : '$val'));
    }

    final partida = root['partida'];
    final mapa = root['mapa'];
    final hist = root['historial'];
    if (mapa is! List) throw const SaveFormatException('Falta la sección "mapa".');
    if (hist is! List) throw const SaveFormatException('Falta la sección "historial".');
    return _RawSave(
      magic: '${root['formato']}',
      version: '${root['version']}',
      meta: sec('partida'),
      tags: partida is Map && partida['etiquetas'] is List
          ? (partida['etiquetas'] as List).map((e) => '$e').toList()
          : const [],
      player: sec('jugador'),
      rows: mapa.map((e) => '$e').toList(),
      config: sec('configuracion'),
      history: [
        for (final h in hist)
          if (h is Map)
            [h['n'], h['dir'], h['desde'], h['hasta'], h['evento'], h['ms']].map((e) => '${e ?? ''}').toList()
          else
            ['?']
      ],
    );
  }

  static _RawSave _fromXml(String content) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(content);
    } on XmlException catch (e) {
      throw SaveFormatException('El XML está incompleto o mal formado: ${e.message}');
    }
    final root = doc.rootElement;
    if (root.name.local != 'partida') {
      throw const SaveFormatException('El XML no contiene un elemento <partida>.');
    }
    XmlElement el(String name) =>
        root.getElement(name) ?? (throw SaveFormatException('Falta el elemento <$name>.'));
    Map<String, String> attrs(XmlElement e) => {for (final a in e.attributes) a.name.local: a.value};

    final meta = attrs(root);
    meta['nombre'] = root.getElement('nombre')?.innerText ?? '';
    final fechas = root.getElement('fechas');
    if (fechas != null) meta.addAll(attrs(fechas));

    return _RawSave(
      magic: meta['formato'] ?? '',
      version: meta['version'] ?? '',
      meta: meta,
      tags: root.getElement('etiquetas')?.findElements('etiqueta').map((e) => e.innerText).toList() ?? const [],
      player: attrs(el('jugador')),
      rows: el('mapa').findElements('fila').map((e) => e.innerText).toList(),
      config: attrs(el('configuracion')),
      history: el('historial').findElements('movimiento').map((e) {
        final a = attrs(e);
        return [a['n'], a['dir'], a['desde'], a['hasta'], a['evento'], a['ms']].map((v) => v ?? '').toList();
      }).toList(),
    );
  }

  static _RawSave _fromTxt(String content) {
    final lines = const LineSplitter().convert(content);
    final header = <String, String>{};
    final sections = <String, List<String>>{};
    String? current;
    var ended = false;
    for (final line in lines) {
      final l = line.trimRight();
      // '#' es comentario, salvo dentro de [MAPA] donde representa una piedra.
      if (l.trim().isEmpty || (current != 'MAPA' && l.startsWith('#'))) continue;
      final m = RegExp(r'^\[([A-ZÁÉÍÓÚ]+)\]$').firstMatch(l.trim());
      if (m != null) {
        current = m.group(1);
        if (current == 'FIN') {
          ended = true;
          break;
        }
        sections[current!] = [];
        continue;
      }
      if (current == null) {
        final i = l.indexOf('=');
        if (i > 0) header[l.substring(0, i).trim()] = l.substring(i + 1).trim();
      } else {
        sections[current]!.add(l);
      }
    }
    if (!ended) {
      throw const SaveFormatException('El archivo de texto está incompleto (falta la marca [FIN]).');
    }
    Map<String, String> kv(String name) {
      final s = sections[name];
      if (s == null) throw SaveFormatException('Falta la sección [$name].');
      final out = <String, String>{};
      for (final l in s) {
        final i = l.indexOf('=');
        if (i <= 0) throw SaveFormatException('Línea inválida en [$name]: "$l".');
        out[l.substring(0, i).trim()] = l.substring(i + 1).trim();
      }
      return out;
    }

    final meta = kv('PARTIDA');
    final rows = sections['MAPA'];
    final hist = sections['HISTORIAL'];
    if (rows == null) throw const SaveFormatException('Falta la sección [MAPA].');
    if (hist == null) throw const SaveFormatException('Falta la sección [HISTORIAL].');
    return _RawSave(
      magic: header['FORMATO'] ?? '',
      version: header['VERSION'] ?? '',
      meta: meta,
      tags: (meta['etiquetas'] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      player: kv('JUGADOR'),
      rows: rows.map((r) => r.trim()).toList(),
      config: kv('CONFIGURACION'),
      history: hist.map((l) => l.split(';')).toList(),
    );
  }

  // ================================================================== validación común

  static GameState _build(_RawSave r) {
    if (r.magic != magic) {
      throw const SaveFormatException('No es una partida de Ruta del Ajolote.');
    }
    final ver = int.tryParse(r.version);
    if (ver == null || ver > version) {
      throw SaveFormatException('Versión de archivo no soportada (${r.version}).');
    }

    String req(Map<String, String> m, String k, String sec) {
      final v = m[k];
      if (v == null || v.isEmpty) throw SaveFormatException('Falta el dato "$k" en $sec.');
      return v;
    }

    int num(Map<String, String> m, String k, String sec, {int min = 0}) {
      final v = int.tryParse(req(m, k, sec));
      if (v == null || v < min) throw SaveFormatException('El dato "$k" en $sec no es un número válido.');
      return v;
    }

    bool flag(Map<String, String> m, String k, bool def) => switch (m[k]) {
          'true' => true,
          'false' => false,
          _ => def,
        };

    // Mapa
    if (r.rows.isEmpty) throw const SaveFormatException('El mapa está vacío.');
    final w = r.rows.first.length;
    if (w < 3 || r.rows.length < 3) throw const SaveFormatException('El mapa es demasiado pequeño.');
    if (r.rows.any((row) => row.length != w)) {
      throw const SaveFormatException('El mapa está dañado: sus filas tienen distinto ancho.');
    }
    final bad = r.rows.join().split('').where((c) => Tile.fromSymbol(c) == null).toSet();
    if (bad.isNotEmpty) throw SaveFormatException('El mapa contiene símbolos desconocidos: ${bad.join(' ')}');
    final grid = GameState.parseRows(r.rows);

    // Partida
    final mode = GameMode.values.asNameMap()[req(r.meta, 'modo', 'la partida')];
    if (mode == null) throw const SaveFormatException('Modo de juego desconocido.');
    final status = GameStatus.values.asNameMap()[req(r.meta, 'estado', 'la partida')];
    if (status == null) throw const SaveFormatException('Estado de partida desconocido.');

    Pos pos(String k) {
      final p = Pos.parse(req(r.player, k, 'el jugador'));
      if (p == null || p.x < 0 || p.y < 0 || p.x >= w || p.y >= r.rows.length || grid[p.y][p.x] == Tile.rock) {
        throw SaveFormatException('La posición "$k" está fuera del mapa o sobre una piedra.');
      }
      return p;
    }

    final player = pos('posicion');
    final start = pos('inicio');

    // Configuración
    final c = r.config;
    final settings = GameSettings(
      sound: flag(c, 'sonido', true),
      vibration: flag(c, 'vibracion', true),
      axolotlColor: GameSettings.colors.contains(c['colorAjolote']) ? c['colorAjolote']! : 'rosa',
      showGrid: flag(c, 'mostrarCuadricula', true),
      timeLimitSec: int.tryParse(c['tiempoLimite'] ?? '') ?? 90,
      difficulty: GameSettings.difficulties.contains(c['dificultad']) ? c['dificultad']! : 'normal',
    );

    // Historial
    final history = <MoveRecord>[];
    for (var i = 0; i < r.history.length; i++) {
      final h = r.history[i];
      final dir = h.length == 6 ? Dir.fromCode(h[1]) : null;
      final from = h.length == 6 ? Pos.parse(h[2]) : null;
      final to = h.length == 6 ? Pos.parse(h[3]) : null;
      final n = h.length == 6 ? int.tryParse(h[0]) : null;
      final ms = h.length == 6 ? int.tryParse(h[5]) : null;
      if (dir == null || from == null || to == null || n == null || ms == null) {
        throw SaveFormatException('El movimiento ${i + 1} del historial está dañado.');
      }
      history.add(MoveRecord(n: n, dir: dir, from: from, to: to, event: h[4], tMs: ms));
    }
    final moves = num(r.player, 'movimientos', 'el jugador');
    if (history.length > moves + 1000) {
      throw const SaveFormatException('El historial no coincide con el número de movimientos.');
    }

    return GameState(
      id: req(r.meta, 'id', 'la partida'),
      name: r.meta['nombre']?.isNotEmpty == true ? r.meta['nombre']! : 'Partida sin nombre',
      tags: r.tags,
      mode: mode,
      level: num(r.meta, 'nivel', 'la partida'),
      seed: num(r.meta, 'semilla', 'la partida'),
      grid: grid,
      start: start,
      player: player,
      lives: num(r.player, 'vidas', 'el jugador'),
      score: num(r.player, 'puntuacion', 'el jugador'),
      moves: moves,
      moveLimit: num(r.player, 'limiteMovimientos', 'el jugador'),
      bubblesCollected: num(r.player, 'burbujas', 'el jugador'),
      elapsedMs: num(r.player, 'tiempoMs', 'el jugador'),
      timeLeftMs: num(r.player, 'tiempoRestanteMs', 'el jugador'),
      status: status,
      settings: settings,
      history: history,
      createdAt: DateTime.tryParse(r.meta['creada'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(r.meta['actualizada'] ?? '') ?? DateTime.now(),
    );
  }
}

class _RawSave {
  final String magic;
  final String version;
  final Map<String, String> meta;
  final List<String> tags;
  final Map<String, String> player;
  final List<String> rows;
  final Map<String, String> config;
  final List<List<String>> history;

  const _RawSave({
    required this.magic,
    required this.version,
    required this.meta,
    required this.tags,
    required this.player,
    required this.rows,
    required this.config,
    required this.history,
  });
}
