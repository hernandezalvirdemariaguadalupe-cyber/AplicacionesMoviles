import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../game/engine.dart';
import '../game/levels.dart';
import '../game/model.dart';
import '../save/repository.dart';
import 'board.dart';
import 'common.dart';
import 'options_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.initial});
  final GameState initial;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameState g = widget.initial.clone();
  late final AppState app = context.read<AppState>();

  // Animación continua (agua, remolinos, partículas)
  late final Ticker _ticker;
  double _time = 0;

  // Movimiento animado del ajolote a lo largo de la ruta
  late Offset _playerPos = Offset(g.player.x.toDouble(), g.player.y.toDouble());
  Dir _facing = Dir.right;
  bool _animating = false;
  final _pops = <Pop>[];
  double _flash = 0;
  double _shake = 0;

  Timer? _clock;
  bool _paused = false;
  bool _ended = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((d) {
      setState(() {
        _time = d.inMicroseconds / 1e6;
        _flash = (_flash - 0.04).clamp(0, 1);
        _shake = (_shake - 0.08).clamp(0, 1);
        _pops.removeWhere((p) => _time - p.born > 0.7);
      });
    })
      ..start();
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_paused || _ended) return;
      if (GameEngine.tick(g, 100)) _finish();
    });
    if (g.status != GameStatus.jugando) WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _clock?.cancel();
    _focus.dispose();
    super.dispose();
  }

  /// Al ir a segundo plano se pausa y se autoguarda: la partida se recupera al volver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive || s == AppLifecycleState.detached) {
      _paused = true;
      _autosave();
    } else if (s == AppLifecycleState.resumed && !_menuOpen) {
      _paused = false;
    }
  }

  bool _menuOpen = false;

  Future<void> _autosave() async {
    if (_ended || g.status != GameStatus.jugando) return;
    try {
      await app.saves.autosave(g, app.saveFormat);
    } catch (_) {
      // El autoguardado nunca interrumpe el juego.
    }
  }

  // ------------------------------------------------------------------ movimiento

  Future<void> _move(Dir d) async {
    if (_animating || _paused || _ended || g.status != GameStatus.jugando) return;
    final before = g.clone();
    final out = GameEngine.move(g, d);
    _facing = d;
    final s = g.settings;
    if (out.blocked) {
      app.play(Sfx.blocked, s);
      setState(() => _shake = 0.6);
      return;
    }
    _animating = true;
    // Recorre la ruta casilla por casilla
    for (var i = 0; i < out.path.length; i++) {
      final p = out.path[i];
      if (before.inside(p) && before.at(p) == Tile.bubble) {
        _pops.add(Pop(Offset(p.x.toDouble(), p.y.toDouble()), _time + 0.1));
      }
      await _animateTo(Offset(p.x.toDouble(), p.y.toDouble()), i == 0 ? 130 : 110);
      if (!mounted) return;
    }
    _animating = false;

    if (out.has('remolino')) {
      app.play(Sfx.hurt, s);
      setState(() => _flash = 1);
    } else if (out.has('mapa_nuevo')) {
      app.play(Sfx.newMap, s);
      snack(context, '¡Mapa despejado! +${GameEngine.mapClearBonus} pts y +10 s');
    } else if (out.has('burbuja')) {
      app.play(Sfx.bubble, s);
    } else if (out.has('salida_cerrada')) {
      app.play(Sfx.blocked, s);
      snack(context, 'La compuerta sigue cerrada: faltan ${g.bubblesLeft} burbujas');
    } else {
      app.play(Sfx.move, s);
    }
    setState(() {});
    if (g.status != GameStatus.jugando) {
      _finish();
    } else {
      _autosave();
    }
  }

  Future<void> _animateTo(Offset target, int ms) async {
    final from = _playerPos;
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
    final a = CurvedAnimation(parent: c, curve: Curves.easeOut);
    a.addListener(() => setState(() => _playerPos = Offset.lerp(from, target, a.value)!));
    await c.forward();
    c.dispose();
  }

  // ------------------------------------------------------------------ fin de partida

  Future<void> _finish() async {
    if (_ended) return;
    _ended = true;
    final stars = GameEngine.stars(g);
    app.recordResult(g, stars);
    await app.saves.clearAutosave();
    if (!mounted) return;
    final won = g.status == GameStatus.ganada;
    final timeUp = g.status == GameStatus.terminada;
    app.play(won || timeUp ? Sfx.win : Sfx.lose, g.settings);
    final hasNext = g.mode == GameMode.aventura && won && g.level + 1 < adventureLevels.length;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(won || timeUp ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            size: 48, color: won || timeUp ? const Color(0xFFD4AF37) : Theme.of(c).colorScheme.error),
        title: Text(won
            ? '¡Nivel superado!'
            : timeUp
                ? '¡Se acabó el tiempo!'
                : (g.lives <= 0 ? 'Sin vidas' : 'Sin movimientos')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (won)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 3; i++)
                Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 40, color: const Color(0xFFD4AF37)),
            ]),
          const SizedBox(height: 8),
          Text('Puntuación: ${g.score}', style: Theme.of(c).textTheme.titleLarge),
          Text('Movimientos: ${g.moves} · Tiempo: ${formatDuration(g.elapsedMs)}'),
          if (timeUp) Text('Mapas despejados: ${g.level - 1} · Récord: ${app.bestTimeAttack}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'menu'), child: const Text('Menú')),
          TextButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Guardar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(c, hasNext ? 'next' : 'retry'),
            child: Text(hasNext ? 'Siguiente' : 'Reintentar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'save':
        await _save();
        if (mounted) Navigator.pop(context);
      case 'next':
        _restart(GameEngine.newAdventure(g.level + 1, app.settings));
      case 'retry':
        _restart(g.mode == GameMode.aventura
            ? GameEngine.newAdventure(g.level, app.settings)
            : GameEngine.newTimeAttack(app.settings));
      default:
        Navigator.pop(context);
    }
  }

  void _restart(GameState n) {
    setState(() {
      g = n;
      _playerPos = Offset(g.player.x.toDouble(), g.player.y.toDouble());
      _ended = false;
      _paused = false;
      _facing = Dir.right;
    });
  }

  // ------------------------------------------------------------------ menú

  Future<void> _save() async {
    final info = await showSaveDialog(context, name: g.name, tags: g.tags, format: app.saveFormat);
    if (info == null || !mounted) return;
    g
      ..name = info.name
      ..tags = info.tags;
    try {
      final f = await app.saves.save(g, info.format);
      if (mounted) snack(context, 'Partida guardada en ${info.format.label} (${f.uri.pathSegments.last})');
    } on SaveIoException catch (e) {
      if (mounted) snack(context, e.message, error: true);
    }
  }

  Future<void> _menu() async {
    if (_ended) return;
    _paused = true;
    _menuOpen = true;
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.pause_circle_outline),
            title: const Text('Juego en pausa'),
            subtitle: Text('${g.name} · ${formatDuration(g.elapsedMs)}'),
          ),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.play_arrow), title: const Text('Reanudar'), onTap: () => Navigator.pop(c)),
          ListTile(
              leading: const Icon(Icons.save_outlined),
              title: const Text('Guardar partida'),
              subtitle: Text('Formato predeterminado: ${app.saveFormat.label}'),
              onTap: () => Navigator.pop(c, 'save')),
          ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Opciones'),
              onTap: () => Navigator.pop(c, 'options')),
          ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reiniciar nivel'),
              onTap: () => Navigator.pop(c, 'restart')),
          ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Salir al menú'),
              subtitle: const Text('El progreso queda autoguardado'),
              onTap: () => Navigator.pop(c, 'exit')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (r) {
      case 'save':
        await _save();
      case 'options':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const OptionsScreen(inGame: true)));
        // Ajustes visuales y de sonido se aplican a la partida actual.
        g.settings = app.settings.copyWith(difficulty: g.settings.difficulty, timeLimitSec: g.settings.timeLimitSec);
      case 'restart':
        if (await confirm(context, 'Reiniciar', 'Se perderá el avance de este nivel.', ok: 'Reiniciar')) {
          _restart(g.mode == GameMode.aventura
              ? GameEngine.newAdventure(g.level, g.settings)
              : GameEngine.newTimeAttack(g.settings));
        }
      case 'exit':
        await _autosave();
        if (mounted) Navigator.pop(context);
        return;
    }
    _menuOpen = false;
    _paused = false;
    _focus.requestFocus();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = g.mode == GameMode.aventura
        ? 'Nivel ${g.level + 1}: ${adventureLevels[g.level].name}'
        : 'Contrarreloj · Mapa ${g.level}';

    final hud = _Hud(g: g);
    final pad = _DPad(onMove: _move);
    final board = Center(
      child: AspectRatio(
        aspectRatio: g.width / g.height,
        child: GestureDetector(
          onPanEnd: (d) {
            final v = d.velocity.pixelsPerSecond;
            if (v.distance < 150) return;
            _move(v.dx.abs() > v.dy.abs() ? (v.dx > 0 ? Dir.right : Dir.left) : (v.dy > 0 ? Dir.down : Dir.up));
          },
          child: Transform.translate(
            offset: Offset(_shake * 6 * (((_time * 40).floor() % 2) * 2 - 1), 0),
            child: CustomPaint(
              painter: BoardPainter(
                state: g,
                player: _playerPos,
                facing: _facing,
                time: _time,
                pops: _pops,
                colors: BoardColors.of(context),
                flash: _flash,
                repaintKey: g.moves,
              ),
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _menu();
      },
      child: KeyboardListener(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (e) {
          if (e is! KeyDownEvent) return;
          final d = switch (e.logicalKey) {
            LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => Dir.up,
            LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => Dir.down,
            LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => Dir.left,
            LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => Dir.right,
            _ => null,
          };
          if (d != null) _move(d);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(title, overflow: TextOverflow.ellipsis),
            leading: IconButton(icon: const Icon(Icons.menu), tooltip: 'Menú', onPressed: _menu),
            actions: [
              IconButton(tooltip: 'Guardar', icon: const Icon(Icons.save_outlined), onPressed: () async {
                _paused = true;
                await _save();
                _paused = false;
              }),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              final landscape = c.maxWidth > c.maxHeight;
              if (landscape) {
                return Row(children: [
                  Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(12), child: board)),
                  SizedBox(
                    width: 280,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [hud, const SizedBox(height: 16), pad]),
                  ),
                ]);
              }
              return Column(children: [
                hud,
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: board)),
                pad,
                const SizedBox(height: 8),
              ]);
            }),
          ),
          backgroundColor: scheme.surface,
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.g});
  final GameState g;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timed = g.mode == GameMode.contrarreloj;
    final lowTime = timed && g.timeLeftMs < 10000;
    Widget stat(IconData i, String v, String label, {Color? color}) => Expanded(
          child: Column(children: [
            Icon(i, color: color ?? scheme.primary, size: 22),
            Text(v, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ]),
        );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          stat(Icons.star_rounded, '${g.score}', 'Puntos', color: const Color(0xFFD4AF37)),
          Expanded(
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < g.settings.startLives; i++)
                  Icon(i < g.lives ? Icons.favorite : Icons.favorite_border, size: 18, color: Colors.redAccent),
              ]),
              const SizedBox(height: 4),
              Text('${g.lives}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Vidas', style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
          timed
              ? stat(Icons.hourglass_bottom, formatDuration(g.timeLeftMs), 'Restante', color: lowTime ? scheme.error : null)
              : stat(Icons.directions_walk, '${g.moveLimit - g.moves}', 'Quedan'),
          stat(Icons.bubble_chart_outlined, '${g.bubblesLeft}', 'Burbujas'),
          stat(Icons.schedule, formatDuration(g.elapsedMs), 'Tiempo'),
        ]),
      ),
    );
  }
}

class _DPad extends StatelessWidget {
  const _DPad({required this.onMove});
  final void Function(Dir) onMove;

  @override
  Widget build(BuildContext context) {
    Widget b(Dir d, IconData i, String tip) => Padding(
          padding: const EdgeInsets.all(3),
          child: IconButton.filledTonal(
            tooltip: tip,
            iconSize: 34,
            onPressed: () => onMove(d),
            icon: Icon(i),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      b(Dir.up, Icons.keyboard_arrow_up, 'Arriba'),
      Row(mainAxisSize: MainAxisSize.min, children: [
        b(Dir.left, Icons.keyboard_arrow_left, 'Izquierda'),
        const SizedBox(width: 56),
        b(Dir.right, Icons.keyboard_arrow_right, 'Derecha'),
      ]),
      b(Dir.down, Icons.keyboard_arrow_down, 'Abajo'),
    ]);
  }
}
