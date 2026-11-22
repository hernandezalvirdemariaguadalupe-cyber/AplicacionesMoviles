import 'dart:collection';
import 'dart:math';

import 'levels.dart';
import 'model.dart';

/// Resultado de un movimiento, usado por la interfaz para animar y sonar.
class MoveOutcome {
  /// Casillas recorridas en orden (incluye empujes de corrientes y regreso al inicio).
  final List<Pos> path;
  final List<String> events;
  final bool blocked;
  final int scoreGained;
  const MoveOutcome({required this.path, required this.events, required this.blocked, this.scoreGained = 0});

  bool has(String e) => events.contains(e);
}

/// Reglas del juego. No depende de Flutter, así se prueba con pruebas unitarias.
class GameEngine {
  static const bubblePoints = 10;
  static const mapClearBonus = 50;
  static const bonusTimeMs = 10000;
  static const maxPushChain = 8;

  // ------------------------------------------------------------------ creación

  static GameState newAdventure(int levelIndex, GameSettings settings) {
    final def = adventureLevels[levelIndex];
    final (grid, start) = _parseLevel(def.rows);
    final now = DateTime.now();
    return GameState(
      id: 'p${now.microsecondsSinceEpoch}',
      name: 'Aventura · ${def.name}',
      tags: const [],
      mode: GameMode.aventura,
      level: levelIndex,
      seed: 0,
      grid: grid,
      start: start,
      player: start,
      lives: settings.startLives,
      score: 0,
      moves: 0,
      moveLimit: def.moveLimit,
      bubblesCollected: 0,
      elapsedMs: 0,
      timeLeftMs: 0,
      status: GameStatus.jugando,
      settings: settings,
      history: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  static GameState newTimeAttack(GameSettings settings, {int? seed}) {
    final now = DateTime.now();
    final s = seed ?? Random().nextInt(1 << 31);
    final (grid, start) = generateMap(s, 1);
    return GameState(
      id: 'p${now.microsecondsSinceEpoch}',
      name: 'Contrarreloj',
      tags: const [],
      mode: GameMode.contrarreloj,
      level: 1,
      seed: s,
      grid: grid,
      start: start,
      player: start,
      lives: settings.startLives,
      score: 0,
      moves: 0,
      moveLimit: 0,
      bubblesCollected: 0,
      elapsedMs: 0,
      timeLeftMs: settings.timeLimitSec * 1000,
      status: GameStatus.jugando,
      settings: settings,
      history: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  static (List<List<Tile>>, Pos) _parseLevel(List<String> rows) {
    var start = const Pos(1, 1);
    final grid = <List<Tile>>[];
    for (var y = 0; y < rows.length; y++) {
      final row = <Tile>[];
      for (var x = 0; x < rows[y].length; x++) {
        final c = rows[y][x];
        if (c == 'S') {
          start = Pos(x, y);
          row.add(Tile.empty);
        } else {
          row.add(Tile.fromSymbol(c) ?? Tile.empty);
        }
      }
      grid.add(row);
    }
    return (grid, start);
  }

  /// Mapa aleatorio reproducible a partir de una semilla (contrarreloj).
  /// Garantiza que todas las burbujas sean alcanzables sin pasar por remolinos.
  static (List<List<Tile>>, Pos) generateMap(int seed, int mapNumber) {
    const w = 7, h = 9;
    final rnd = Random(seed * 31 + mapNumber);
    for (var attempt = 0; attempt < 200; attempt++) {
      final g = List.generate(h, (y) => List.generate(w, (x) {
            final border = x == 0 || y == 0 || x == w - 1 || y == h - 1;
            return border ? Tile.rock : Tile.empty;
          }));
      final free = <Pos>[for (var y = 1; y < h - 1; y++) for (var x = 1; x < w - 1; x++) Pos(x, y)]..shuffle(rnd);
      var i = 0;
      final start = free[i++];
      void place(Tile t, int n) {
        for (var k = 0; k < n && i < free.length; k++) {
          final p = free[i++];
          g[p.y][p.x] = t;
        }
      }

      place(Tile.rock, 5 + rnd.nextInt(3));
      place(Tile.whirlpool, min(2 + mapNumber ~/ 2, 5));
      place([Tile.currentUp, Tile.currentDown, Tile.currentLeft, Tile.currentRight][rnd.nextInt(4)], 1);
      place([Tile.currentUp, Tile.currentDown, Tile.currentLeft, Tile.currentRight][rnd.nextInt(4)], 1);
      place(Tile.bubble, 6);

      // Todas las burbujas deben ser alcanzables evitando piedras y remolinos.
      final seen = <Pos>{start};
      final q = Queue<Pos>()..add(start);
      while (q.isNotEmpty) {
        final p = q.removeFirst();
        for (final d in Dir.values) {
          final n = p.step(d);
          final t = g[n.y][n.x];
          if (t == Tile.rock || t == Tile.whirlpool || seen.contains(n)) continue;
          seen.add(n);
          q.add(n);
        }
      }
      final ok = [
        for (var y = 0; y < h; y++)
          for (var x = 0; x < w; x++)
            if (g[y][x] == Tile.bubble) seen.contains(Pos(x, y))
      ].every((v) => v);
      if (ok) return (g, start);
    }
    // Respaldo (prácticamente imposible llegar aquí): mapa abierto.
    final (g, s) = _parseLevel(adventureLevels.first.rows);
    for (final r in g) {
      for (var x = 0; x < r.length; x++) {
        if (r[x] == Tile.exit) r[x] = Tile.bubble;
      }
    }
    return (g, s);
  }

  // ------------------------------------------------------------------ reglas

  /// Aplica un movimiento al estado (lo modifica) y devuelve qué pasó.
  static MoveOutcome move(GameState s, Dir dir) {
    if (s.status != GameStatus.jugando) {
      return const MoveOutcome(path: [], events: ['fin'], blocked: true);
    }
    final from = s.player;
    final target = from.step(dir);
    if (!s.inside(target) || s.at(target) == Tile.rock) {
      return MoveOutcome(path: [from], events: const ['bloqueado'], blocked: true);
    }

    s.moves++;
    final path = <Pos>[target];
    final events = <String>[];
    var gained = 0;
    var pos = target;

    for (var chain = 0; chain <= maxPushChain; chain++) {
      final t = s.at(pos);
      if (t == Tile.bubble) {
        s.grid[pos.y][pos.x] = Tile.empty;
        s.bubblesCollected++;
        gained += bubblePoints;
        events.add('burbuja');
      } else if (t == Tile.whirlpool) {
        s.lives--;
        events.add('remolino');
        pos = s.start;
        path.add(pos);
        break;
      } else if (t == Tile.exit) {
        events.add(s.bubblesLeft == 0 ? 'salida' : 'salida_cerrada');
      }
      final push = t.push;
      if (push == null) break;
      final next = pos.step(push);
      if (!s.inside(next) || s.at(next) == Tile.rock) break;
      events.add('corriente');
      pos = next;
      path.add(pos);
    }
    s.player = pos;
    s.score += gained;

    // Fin de mapa / partida
    if (s.mode == GameMode.contrarreloj && s.bubblesLeft == 0) {
      s.level++;
      final (g, st) = generateMap(s.seed, s.level);
      s.grid = g;
      s.start = st;
      s.player = st;
      s.score += mapClearBonus;
      gained += mapClearBonus;
      s.timeLeftMs += bonusTimeMs;
      events.add('mapa_nuevo');
      path.add(st);
    }
    if (events.contains('salida')) {
      final bonus = max(0, s.moveLimit - s.moves) * 5 + s.lives * 20;
      s.score += bonus;
      gained += bonus;
      s.status = GameStatus.ganada;
    } else if (s.lives <= 0) {
      s.lives = 0;
      s.status = GameStatus.perdida;
    } else if (s.mode == GameMode.aventura && s.moveLimit > 0 && s.moves >= s.moveLimit) {
      s.status = GameStatus.perdida;
      events.add('sin_movimientos');
    }
    if (events.isEmpty) events.add('movio');

    s.history.add(MoveRecord(
      n: s.moves,
      dir: dir,
      from: from,
      to: s.player,
      event: events.join('+'),
      tMs: s.elapsedMs,
    ));
    s.updatedAt = DateTime.now();
    return MoveOutcome(path: path, events: events, blocked: false, scoreGained: gained);
  }

  /// Avanza el reloj. Devuelve true si el tiempo de contrarreloj se agotó en este paso.
  static bool tick(GameState s, int dtMs) {
    if (s.status != GameStatus.jugando) return false;
    s.elapsedMs += dtMs;
    if (s.mode == GameMode.contrarreloj) {
      s.timeLeftMs -= dtMs;
      if (s.timeLeftMs <= 0) {
        s.timeLeftMs = 0;
        s.status = GameStatus.terminada;
        return true;
      }
    }
    return false;
  }

  /// Estrellas (1-3) al completar un nivel de Aventura.
  static int stars(GameState s) {
    if (s.status != GameStatus.ganada) return 0;
    final noDamage = s.lives == s.settings.startLives;
    final ratio = s.moveLimit == 0 ? 0 : s.moves / s.moveLimit;
    if (noDamage && ratio <= 0.8) return 3;
    if (ratio <= 0.9) return 2;
    return 1;
  }
}
