import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../game/engine.dart';
import '../game/levels.dart';
import '../game/model.dart';
import 'board.dart';
import 'common.dart';
import 'game_screen.dart';
import 'options_screen.dart';
import 'saves_screen.dart';

/// Permite a la portada saber cuándo vuelve a ser visible (por cualquier ruta).
final routeObserver = RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  GameState? autosave;
  String? autosaveError;

  AppState get app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _checkAutosave();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Al regresar a la portada desde cualquier pantalla se relee el autoguardado.
  @override
  void didPopNext() => _checkAutosave();

  /// Persistencia robusta: si la app se cerró a mitad de una partida, se ofrece continuarla.
  Future<void> _checkAutosave() async {
    final (s, err) = await app.saves.loadAutosave();
    if (!mounted) return;
    setState(() {
      autosave = s?.status == GameStatus.jugando ? s : null;
      autosaveError = err;
    });
    if (err != null) {
      snack(context, 'El autoguardado estaba dañado y se descartó: $err', error: true);
      await app.saves.clearAutosave();
    }
  }

  Future<void> _play(GameState s) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(initial: s)));
    _checkAutosave();
  }

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _checkAutosave();
  }

  Future<void> _newGame(Future<void> Function() start) async {
    if (autosave != null &&
        !await confirm(context, 'Partida en curso',
            'Tienes una partida sin terminar. Si empiezas otra, el autoguardado se reemplazará (las partidas guardadas no se tocan).',
            ok: 'Empezar nueva')) {
      return;
    }
    await start();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final totalStars = state.stars.values.fold(0, (a, b) => a + b);

    final menu = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (autosave != null) ...[
        FilledButton.icon(
          onPressed: () => _play(autosave!),
          icon: const Icon(Icons.play_arrow),
          label: Text('Continuar: ${autosave!.mode == GameMode.aventura ? 'Nivel ${autosave!.level + 1}' : 'Contrarreloj'}'
              ' · ${autosave!.score} pts'),
        ),
        const SizedBox(height: 10),
      ],
      FilledButton.tonalIcon(
        onPressed: () => _newGame(() => _go(const LevelSelectScreen())),
        icon: const Icon(Icons.map_outlined),
        label: const Text('Aventura'),
      ),
      const SizedBox(height: 10),
      FilledButton.tonalIcon(
        onPressed: () => _newGame(() => _play(GameEngine.newTimeAttack(state.settings))),
        icon: const Icon(Icons.timer_outlined),
        label: Text('Contrarreloj (${state.settings.timeLimitSec} s)'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
        onPressed: () => _go(const SavesScreen()),
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('Partidas guardadas'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
        onPressed: () => _go(const OptionsScreen()),
        icon: const Icon(Icons.tune),
        label: const Text('Opciones'),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Stat(icon: Icons.star_rounded, value: '$totalStars/${adventureLevels.length * 3}', label: 'Estrellas'),
            _Stat(icon: Icons.lock_open, value: '${state.unlocked}/${adventureLevels.length}', label: 'Niveles'),
            _Stat(icon: Icons.emoji_events_outlined, value: '${state.bestTimeAttack}', label: 'Récord ⏱'),
          ]),
        ),
      ),
    ]);

    final header = Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 150, width: 260, child: _AnimatedLogo()),
      const SizedBox(height: 12),
      Text('Ruta del Ajolote',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
      const SizedBox(height: 4),
      Text('Recolecta burbujas por los canales de Xochimilco', textAlign: TextAlign.center, style: TextStyle(color: scheme.outline)),
    ]);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth > c.maxHeight && c.maxWidth > 600) {
            return Row(children: [
              Expanded(child: Center(child: header)),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: menu)),
            ]);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(children: [header, const SizedBox(height: 28), menu]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: const Color(0xFFD4AF37)),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

/// Pequeño canal animado con el ajolote para la portada.
class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();
  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo> with SingleTickerProviderStateMixin {
  late final Ticker _t;
  double time = 0;
  late final GameState demo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    demo = GameState(
      id: 'demo',
      name: '',
      tags: const [],
      mode: GameMode.aventura,
      level: 0,
      seed: 0,
      grid: GameState.parseRows(['.o..@', '..>.o']),
      start: const Pos(0, 1),
      player: const Pos(1, 1),
      lives: 3,
      score: 0,
      moves: 0,
      moveLimit: 0,
      bubblesCollected: 0,
      elapsedMs: 0,
      timeLeftMs: 0,
      status: GameStatus.jugando,
      settings: context.read<AppState>().settings.copyWith(showGrid: false),
      history: const [],
      createdAt: now,
      updatedAt: now,
    );
    _t = createTicker((d) => setState(() => time = d.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    demo.settings = context.watch<AppState>().settings.copyWith(showGrid: false);
    final x = 1 + (time * 0.5 % 2 < 1 ? time * 0.5 % 1 : 1 - time * 0.5 % 1) * 2;
    return CustomPaint(
      painter: BoardPainter(
        state: demo,
        player: Offset(x, 1),
        facing: time * 0.5 % 2 < 1 ? Dir.right : Dir.left,
        time: time,
        pops: const [],
        colors: BoardColors.of(context),
        flash: 0,
        repaintKey: 0,
      ),
    );
  }
}

/// Selección de nivel con candados, estrellas y mejor puntuación.
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Aventura')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.95),
        itemCount: adventureLevels.length,
        itemBuilder: (_, i) {
          final locked = i >= app.unlocked;
          final st = app.stars[i] ?? 0;
          return Card(
            color: locked ? scheme.surfaceContainerHighest : scheme.primaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: locked
                  ? () => snack(context, 'Supera el nivel $i para desbloquearlo')
                  : () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => GameScreen(initial: GameEngine.newAdventure(i, app.settings))),
                      ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(locked ? Icons.lock_outline : Icons.water, size: 32, color: locked ? scheme.outline : scheme.primary),
                  const SizedBox(height: 6),
                  Text('Nivel ${i + 1}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(adventureLevels[i].name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var k = 0; k < 3; k++)
                      Icon(k < st ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: const Color(0xFFD4AF37)),
                  ]),
                  if (app.bestScores[i] != null)
                    Text('Récord: ${app.bestScores[i]}', style: Theme.of(context).textTheme.labelSmall),
                  Text('Límite: ${adventureLevels[i].moveLimit} movs', style: Theme.of(context).textTheme.labelSmall),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
