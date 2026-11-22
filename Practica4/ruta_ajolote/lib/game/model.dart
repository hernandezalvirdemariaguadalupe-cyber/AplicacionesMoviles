/// Modelo del juego "Ruta del Ajolote".
///
/// Un ajolote recorre un canal de Xochimilco (cuadrícula) recolectando burbujas de
/// oxígeno. Las piedras bloquean, los remolinos quitan una vida y lo regresan al
/// inicio, y las corrientes lo empujan una casilla extra. En Aventura debe llegar
/// a la compuerta (abierta sólo con todas las burbujas) antes de agotar sus
/// movimientos; en Contrarreloj junta tantas burbujas como pueda antes de que se
/// acabe el tiempo.
library;

enum Tile {
  empty('.'),
  rock('#'),
  bubble('o'),
  whirlpool('@'),
  exit('E'),
  currentUp('^'),
  currentDown('v'),
  currentLeft('<'),
  currentRight('>');

  const Tile(this.symbol);
  final String symbol;

  static Tile? fromSymbol(String s) {
    for (final t in values) {
      if (t.symbol == s) return t;
    }
    return null;
  }

  Dir? get push => switch (this) {
        currentUp => Dir.up,
        currentDown => Dir.down,
        currentLeft => Dir.left,
        currentRight => Dir.right,
        _ => null,
      };
}

enum Dir {
  up('U', 0, -1),
  down('D', 0, 1),
  left('L', -1, 0),
  right('R', 1, 0);

  const Dir(this.code, this.dx, this.dy);
  final String code;
  final int dx;
  final int dy;

  static Dir? fromCode(String c) {
    for (final d in values) {
      if (d.code == c) return d;
    }
    return null;
  }

  String get label => switch (this) { up => '↑', down => '↓', left => '←', right => '→' };
}

enum GameMode {
  aventura('Aventura'),
  contrarreloj('Contrarreloj');

  const GameMode(this.label);
  final String label;
}

enum GameStatus { jugando, ganada, perdida, terminada }

class Pos {
  final int x;
  final int y;
  const Pos(this.x, this.y);
  Pos step(Dir d) => Pos(x + d.dx, y + d.dy);
  @override
  bool operator ==(Object other) => other is Pos && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => '$x,$y';

  static Pos? parse(String s) {
    final p = s.split(',');
    if (p.length != 2) return null;
    final x = int.tryParse(p[0].trim()), y = int.tryParse(p[1].trim());
    return x == null || y == null ? null : Pos(x, y);
  }
}

/// Un movimiento del historial.
class MoveRecord {
  final int n; // número de movimiento (1..)
  final Dir dir;
  final Pos from;
  final Pos to;
  final String event; // movio, burbuja, remolino, corriente, bloqueado, salida, salida_cerrada, mapa_nuevo
  final int tMs; // tiempo de juego en que ocurrió

  const MoveRecord({
    required this.n,
    required this.dir,
    required this.from,
    required this.to,
    required this.event,
    required this.tMs,
  });

  Map<String, dynamic> toJson() =>
      {'n': n, 'dir': dir.code, 'desde': '$from', 'hasta': '$to', 'evento': event, 'ms': tMs};
}

/// Configuraciones personalizadas del jugador que viajan dentro de cada partida.
class GameSettings {
  final bool sound;
  final bool vibration;
  final String axolotlColor; // rosa | dorado | azul | verde
  final bool showGrid;
  final int timeLimitSec; // contrarreloj
  final String difficulty; // facil | normal | dificil

  const GameSettings({
    this.sound = true,
    this.vibration = true,
    this.axolotlColor = 'rosa',
    this.showGrid = true,
    this.timeLimitSec = 90,
    this.difficulty = 'normal',
  });

  static const colors = ['rosa', 'dorado', 'azul', 'verde'];
  static const difficulties = ['facil', 'normal', 'dificil'];
  static const timeLimits = [60, 90, 120];

  int get startLives => switch (difficulty) { 'facil' => 5, 'dificil' => 2, _ => 3 };

  GameSettings copyWith({
    bool? sound,
    bool? vibration,
    String? axolotlColor,
    bool? showGrid,
    int? timeLimitSec,
    String? difficulty,
  }) =>
      GameSettings(
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        axolotlColor: axolotlColor ?? this.axolotlColor,
        showGrid: showGrid ?? this.showGrid,
        timeLimitSec: timeLimitSec ?? this.timeLimitSec,
        difficulty: difficulty ?? this.difficulty,
      );

  Map<String, dynamic> toJson() => {
        'sonido': sound,
        'vibracion': vibration,
        'colorAjolote': axolotlColor,
        'mostrarCuadricula': showGrid,
        'tiempoLimite': timeLimitSec,
        'dificultad': difficulty,
      };
}

/// Estado completo y recuperable de una partida.
class GameState {
  String id;
  String name;
  List<String> tags;
  final GameMode mode;
  int level; // índice de nivel (aventura) o número de mapa (contrarreloj)
  int seed; // semilla del mapa aleatorio (contrarreloj)
  List<List<Tile>> grid;
  Pos start;
  Pos player;
  int lives;
  int score;
  int moves;
  int moveLimit; // 0 = sin límite
  int bubblesCollected; // total en la partida
  int elapsedMs;
  int timeLeftMs; // sólo contrarreloj
  GameStatus status;
  GameSettings settings;
  List<MoveRecord> history;
  DateTime createdAt;
  DateTime updatedAt;

  GameState({
    required this.id,
    required this.name,
    required this.tags,
    required this.mode,
    required this.level,
    required this.seed,
    required this.grid,
    required this.start,
    required this.player,
    required this.lives,
    required this.score,
    required this.moves,
    required this.moveLimit,
    required this.bubblesCollected,
    required this.elapsedMs,
    required this.timeLeftMs,
    required this.status,
    required this.settings,
    required this.history,
    required this.createdAt,
    required this.updatedAt,
  });

  int get width => grid.isEmpty ? 0 : grid[0].length;
  int get height => grid.length;

  Tile at(Pos p) => grid[p.y][p.x];
  bool inside(Pos p) => p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;

  int get bubblesLeft => grid.fold(0, (a, r) => a + r.where((t) => t == Tile.bubble).length);

  List<String> get gridRows => grid.map((r) => r.map((t) => t.symbol).join()).toList();

  static List<List<Tile>> parseRows(List<String> rows) =>
      rows.map((r) => r.split('').map((c) => Tile.fromSymbol(c) ?? Tile.empty).toList()).toList();

  GameState clone() => GameState(
        id: id,
        name: name,
        tags: [...tags],
        mode: mode,
        level: level,
        seed: seed,
        grid: grid.map((r) => [...r]).toList(),
        start: start,
        player: player,
        lives: lives,
        score: score,
        moves: moves,
        moveLimit: moveLimit,
        bubblesCollected: bubblesCollected,
        elapsedMs: elapsedMs,
        timeLeftMs: timeLeftMs,
        status: status,
        settings: settings,
        history: [...history],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
