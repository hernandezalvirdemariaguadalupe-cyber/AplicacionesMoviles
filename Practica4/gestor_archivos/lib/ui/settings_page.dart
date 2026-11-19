import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../data/app_state.dart';
import 'common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<(int, int)> usage = context.read<AppState>().thumbnails.diskUsage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _title('Tema institucional'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (final p in AppPalette.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => state.setPalette(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: state.palette == p ? scheme.primary : scheme.outlineVariant,
                              width: state.palette == p ? 3 : 1),
                        ),
                        child: Column(children: [
                          CircleAvatar(
                            backgroundColor: p.primary,
                            radius: 22,
                            child: state.palette == p ? const Icon(Icons.check, color: Colors.white) : null,
                          ),
                          const SizedBox(height: 8),
                          Text(p.label, textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          _title('Modo de color'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Sistema')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Claro')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Oscuro')),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (s) => state.setThemeMode(s.first),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('“Sistema” sigue automáticamente el modo claro/oscuro del dispositivo.'),
          ),
          _title('Caché de miniaturas'),
          FutureBuilder<(int, int)>(
            future: usage,
            builder: (_, snap) {
              final (files, bytes) = snap.data ?? (0, 0);
              final t = state.thumbnails;
              return ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('$files miniaturas · ${formatSize(bytes)}'),
                subtitle: Text('Aciertos: ${t.hits} · Generadas: ${t.misses} (esta sesión)'),
                trailing: TextButton(
                  onPressed: () async {
                    await t.clear();
                    setState(() => usage = t.diskUsage());
                    if (context.mounted) showOk(context, 'Caché de miniaturas vaciada');
                  },
                  child: const Text('Vaciar'),
                ),
              );
            },
          ),
          _title('Datos persistentes'),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text('${state.recents.length} recientes · ${state.favorites.length} favoritos'),
            subtitle: const Text('Guardados con SharedPreferences (Android) / NSUserDefaults (iOS)'),
          ),
          _title('Acerca de'),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Práctica 4 · ESCOM-IPN'),
            subtitle: Text('Flutter · ${Platform.operatingSystem} ${Platform.operatingSystemVersion}'),
          ),
          const ListTile(
            leading: Icon(Icons.wifi_off),
            title: Text('Funciona 100 % sin conexión'),
            subtitle: Text('No se solicitan permisos de almacenamiento global ni de Internet.'),
          ),
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(t,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
