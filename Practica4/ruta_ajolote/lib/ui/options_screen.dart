import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../game/model.dart';
import '../save/codec.dart';
import 'saves_screen.dart';

/// Menú de opciones: formato de guardado, gestión de partidas, aspectos visuales y
/// de jugabilidad.
class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key, this.inGame = false});
  final bool inGame;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    final scheme = Theme.of(context).colorScheme;

    Widget title(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Opciones')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          title('Guardado'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<SaveFormat>(
              segments: [
                for (final f in SaveFormat.values)
                  ButtonSegment(value: f, label: Text(f.ext.toUpperCase()), icon: const Icon(Icons.description_outlined)),
              ],
              selected: {app.saveFormat},
              onSelectionChanged: (v) => app.setSaveFormat(v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Formato predeterminado para guardar y autoguardar: ${app.saveFormat.label}.'),
          ),
          if (!inGame)
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Gestionar partidas guardadas'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavesScreen())),
            ),
          title('Tema'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (final p in AppPalette.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        side: BorderSide(color: app.palette == p ? scheme.primary : scheme.outlineVariant, width: app.palette == p ? 3 : 1),
                      ),
                      onPressed: () => app.setPalette(p),
                      icon: CircleAvatar(radius: 10, backgroundColor: p.primary),
                      label: Text(p.label),
                    ),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (v) => app.setThemeMode(v.first),
            ),
          ),
          title('Aspecto del juego'),
          ListTile(
            title: const Text('Color del ajolote'),
            subtitle: Wrap(spacing: 10, children: [
              for (final c in GameSettings.colors)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: BoardColors.axolotl(c)),
                  label: Text(c[0].toUpperCase() + c.substring(1)),
                  selected: s.axolotlColor == c,
                  onSelected: (_) => app.setSettings(s.copyWith(axolotlColor: c)),
                ),
            ]),
          ),
          SwitchListTile(
            title: const Text('Mostrar cuadrícula'),
            value: s.showGrid,
            onChanged: (v) => app.setSettings(s.copyWith(showGrid: v)),
          ),
          title('Sonido y vibración'),
          SwitchListTile(
            title: const Text('Efectos de sonido'),
            value: s.sound,
            onChanged: (v) {
              app.setSettings(s.copyWith(sound: v));
              if (v) app.play(Sfx.bubble, s.copyWith(sound: true));
            },
          ),
          SwitchListTile(
            title: const Text('Vibración'),
            value: s.vibration,
            onChanged: (v) => app.setSettings(s.copyWith(vibration: v)),
          ),
          title('Jugabilidad'),
          ListTile(
            title: const Text('Dificultad'),
            subtitle: Text(inGame ? 'Se aplica a partidas nuevas' : 'Vidas al iniciar: ${s.startLives}'),
            trailing: DropdownButton<String>(
              value: s.difficulty,
              items: const [
                DropdownMenuItem(value: 'facil', child: Text('Fácil (5 ♥)')),
                DropdownMenuItem(value: 'normal', child: Text('Normal (3 ♥)')),
                DropdownMenuItem(value: 'dificil', child: Text('Difícil (2 ♥)')),
              ],
              onChanged: (v) => app.setSettings(s.copyWith(difficulty: v)),
            ),
          ),
          ListTile(
            title: const Text('Tiempo de contrarreloj'),
            subtitle: Text(inGame ? 'Se aplica a partidas nuevas' : 'Cada mapa despejado suma 10 s'),
            trailing: DropdownButton<int>(
              value: s.timeLimitSec,
              items: [for (final t in GameSettings.timeLimits) DropdownMenuItem(value: t, child: Text('$t s'))],
              onChanged: (v) => app.setSettings(s.copyWith(timeLimitSec: v)),
            ),
          ),
        ],
      ),
    );
  }
}
