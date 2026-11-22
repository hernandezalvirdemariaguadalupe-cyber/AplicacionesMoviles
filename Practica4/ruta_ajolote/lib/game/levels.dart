/// Niveles del modo Aventura.
/// Símbolos: '#' piedra · '.' agua · 'o' burbuja · '@' remolino · 'E' compuerta ·
/// '^ v < >' corrientes · 'S' inicio del ajolote.
/// La prueba `test/engine_test.dart` verifica con búsqueda en anchura que cada nivel
/// se puede resolver dentro de su límite de movimientos.
class LevelDef {
  final String name;
  final List<String> rows;
  final int moveLimit;
  const LevelDef(this.name, this.rows, this.moveLimit);
}

const adventureLevels = <LevelDef>[
  LevelDef('Primer chapuzón', [
    '#######',
    '#S..o.#',
    '#.###.#',
    '#.o...#',
    '#.#.#.#',
    '#...o.#',
    '###.###',
    '#..E..#',
    '#######',
  ], 20),
  LevelDef('Remolinos de Xochimilco', [
    '#######',
    '#S.@.o#',
    '#.#.#.#',
    '#o..@.#',
    '#.#.#.#',
    '#..o..#',
    '#@#.#.#',
    '#..E.o#',
    '#######',
  ], 26),
  LevelDef('Corrientes traviesas', [
    '#######',
    '#S>..o#',
    '#.#v#.#',
    '#o.v..#',
    '#.#.#@#',
    '#<..o.#',
    '#.#^#.#',
    '#o.E..#',
    '#######',
  ], 24),
  LevelDef('Laberinto de chinampas', [
    '#######',
    '#S#o..#',
    '#.#.#.#',
    '#...#o#',
    '###.#.#',
    '#o@...#',
    '#.###v#',
    '#..E<o#',
    '#######',
  ], 28),
  LevelDef('El gran canal', [
    '#########',
    '#S..#..o#',
    '#.#.#.#.#',
    '#o#...#.#',
    '#.###@#.#',
    '#...>.o.#',
    '#@#v###.#',
    '#o..E..o#',
    '#########',
  ], 36),
];
