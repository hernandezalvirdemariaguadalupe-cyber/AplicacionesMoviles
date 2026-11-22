import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_ajolote/game/engine.dart';
import 'package:ruta_ajolote/game/model.dart';
import 'package:ruta_ajolote/save/codec.dart';

GameState sample() {
  final s = GameEngine.newAdventure(1, const GameSettings(axolotlColor: 'azul', difficulty: 'facil', sound: false))
    ..name = 'Mi partida = prueba'
    ..tags = ['Récord', 'práctica'];
  for (final d in [Dir.right, Dir.down, Dir.down, Dir.left, Dir.right, Dir.right]) {
    GameEngine.move(s, d);
  }
  s.elapsedMs = 12345;
  return s;
}

void main() {
  for (final f in SaveFormat.values) {
    test('${f.label}: guardar y cargar conserva todo el estado', () {
      final s = sample();
      final text = SaveCodec.encode(s, f);
      final r = SaveCodec.decode(text, f);
      expect(r.id, s.id);
      expect(r.name, s.name);
      expect(r.tags, s.tags);
      expect(r.mode, s.mode);
      expect(r.level, s.level);
      expect(r.gridRows, s.gridRows);
      expect(r.player, s.player);
      expect(r.start, s.start);
      expect(r.lives, s.lives);
      expect(r.score, s.score);
      expect(r.moves, s.moves);
      expect(r.moveLimit, s.moveLimit);
      expect(r.bubblesCollected, s.bubblesCollected);
      expect(r.elapsedMs, 12345);
      expect(r.status, s.status);
      expect(r.settings.axolotlColor, 'azul');
      expect(r.settings.difficulty, 'facil');
      expect(r.settings.sound, isFalse);
      expect(r.history.length, s.history.length);
      expect(r.history.last.event, s.history.last.event);
      expect(r.history.last.to, s.history.last.to);
    });

    test('${f.label}: archivo vacío da error legible', () {
      expect(() => SaveCodec.decode('   ', f),
          throwsA(isA<SaveFormatException>().having((e) => e.message, 'msg', contains('vacío'))));
    });

    test('${f.label}: archivo cortado a la mitad da error legible', () {
      final text = SaveCodec.encode(sample(), f);
      expect(() => SaveCodec.decode(text.substring(0, text.length ~/ 2), f), throwsA(isA<SaveFormatException>()));
    });
  }

  test('contenido corrupto: fila de mapa con otro ancho', () {
    final text = SaveCodec.encode(sample(), SaveFormat.json).replaceFirst('"#.#.#.#"', '"#.#.#"');
    expect(() => SaveCodec.decode(text, SaveFormat.json),
        throwsA(isA<SaveFormatException>().having((e) => e.message, 'msg', contains('ancho'))));
  });

  test('contenido corrupto: posición sobre una piedra', () {
    final s = sample()..player = const Pos(0, 0);
    final text = SaveCodec.encode(s, SaveFormat.xml);
    expect(() => SaveCodec.decode(text, SaveFormat.xml), throwsA(isA<SaveFormatException>()));
  });

  test('contenido ajeno: no es una partida', () {
    expect(() => SaveCodec.decode('{"hola": 1}', SaveFormat.json), throwsA(isA<SaveFormatException>()));
    expect(() => SaveCodec.decode('<a/>', SaveFormat.xml), throwsA(isA<SaveFormatException>()));
  });

  test('detección de formato por contenido', () {
    expect(SaveFormat.sniff('  {"a":1}'), SaveFormat.json);
    expect(SaveFormat.sniff('<?xml'), SaveFormat.xml);
    expect(SaveFormat.sniff('# Ruta'), SaveFormat.txt);
  });
}
