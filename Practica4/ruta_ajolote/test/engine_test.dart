import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_ajolote/game/engine.dart';
import 'package:ruta_ajolote/game/levels.dart';
import 'package:ruta_ajolote/game/model.dart';

/// Búsqueda en anchura sobre estados reales del motor: devuelve el mínimo de
/// movimientos para ganar el nivel, o null si no tiene solución.
int? shortestWin(GameState initial) {
  String key(GameState s) => '${s.player}|${s.lives}|${s.gridRows.join()}';
  final seen = <String>{key(initial)};
  final q = Queue<GameState>()..add(initial);
  while (q.isNotEmpty) {
    final s = q.removeFirst();
    for (final d in Dir.values) {
      final n = s.clone();
      final out = GameEngine.move(n, d);
      if (out.blocked) continue;
      if (n.status == GameStatus.ganada) return n.moves;
      if (n.status != GameStatus.jugando) continue;
      if (seen.add(key(n))) q.add(n);
    }
  }
  return null;
}

void main() {
  const settings = GameSettings(difficulty: 'normal');

  for (var i = 0; i < adventureLevels.length; i++) {
    test('nivel ${i + 1} (${adventureLevels[i].name}) tiene solución dentro del límite', () {
      final s = GameEngine.newAdventure(i, settings)..moveLimit = 999;
      final best = shortestWin(s);
      // ignore: avoid_print
      print('Nivel ${i + 1}: mínimo $best movimientos, límite ${adventureLevels[i].moveLimit}');
      expect(best, isNotNull);
      expect(best!, lessThanOrEqualTo(adventureLevels[i].moveLimit));
    });
  }

  test('piedra bloquea sin contar movimiento', () {
    final s = GameEngine.newAdventure(0, settings);
    final out = GameEngine.move(s, Dir.up);
    expect(out.blocked, isTrue);
    expect(s.moves, 0);
  });

  test('remolino quita vida y regresa al inicio', () {
    final s = GameEngine.newAdventure(1, settings); // remolino en (3,1)
    GameEngine.move(s, Dir.right);
    final out = GameEngine.move(s, Dir.right);
    expect(out.has('remolino'), isTrue);
    expect(s.lives, settings.startLives - 1);
    expect(s.player, s.start);
  });

  test('corriente empuja una casilla extra', () {
    final s = GameEngine.newAdventure(2, settings); // '>' en (2,1)
    final out = GameEngine.move(s, Dir.right);
    expect(out.has('corriente'), isTrue);
    expect(s.player, const Pos(3, 1));
  });

  test('compuerta cerrada con burbujas pendientes', () {
    final s = GameEngine.newAdventure(0, settings);
    for (final d in [Dir.down, Dir.down, Dir.down, Dir.down, Dir.right, Dir.right, Dir.down, Dir.down]) {
      GameEngine.move(s, d);
    }
    expect(s.player, const Pos(3, 7));
    expect(s.history.last.event, contains('salida_cerrada'));
    expect(s.status, GameStatus.jugando);
  });

  test('contrarreloj: mapa reproducible por semilla y tiempo agotado', () {
    final a = GameEngine.newTimeAttack(settings, seed: 42);
    final b = GameEngine.newTimeAttack(settings, seed: 42);
    expect(a.gridRows, b.gridRows);
    expect(a.bubblesLeft, 6);
    expect(GameEngine.tick(a, settings.timeLimitSec * 1000), isTrue);
    expect(a.status, GameStatus.terminada);
  });
}
