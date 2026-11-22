import 'package:flutter/material.dart';

import '../game/model.dart';
import '../save/codec.dart';

void snack(BuildContext context, String msg, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: error ? scheme.errorContainer : null,
      content: Row(children: [
        if (error) Icon(Icons.error_outline, color: scheme.onErrorContainer),
        if (error) const SizedBox(width: 12),
        Expanded(child: Text(msg, style: error ? TextStyle(color: scheme.onErrorContainer) : null)),
      ]),
    ));
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String ok = 'Aceptar', bool destructive = false}) async {
  final scheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: destructive ? Icon(Icons.warning_amber_rounded, color: scheme.error) : null,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: scheme.error, minimumSize: const Size(0, 40))
                  : FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(c, true),
              child: Text(ok),
            ),
          ],
        ),
      ) ??
      false;
}

String formatDuration(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

String formatSize(int b) => b < 1024 ? '$b B' : '${(b / 1024).toStringAsFixed(1)} KB';

const suggestedTags = ['Favorita', 'Récord', 'Práctica', 'Difícil', 'Para mostrar'];

/// Resultado del diálogo de guardar / editar etiquetas.
class SaveInfo {
  final String name;
  final List<String> tags;
  final SaveFormat format;
  const SaveInfo(this.name, this.tags, this.format);
}

/// Diálogo para nombrar, etiquetar y elegir el formato de una partida.
Future<SaveInfo?> showSaveDialog(BuildContext context,
    {required String name, required List<String> tags, required SaveFormat format, bool askFormat = true, String title = 'Guardar partida'}) {
  final nameCtrl = TextEditingController(text: name);
  final tagCtrl = TextEditingController();
  final selected = {...tags};
  var fmt = format;
  return showDialog<SaveInfo>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        final all = {...suggestedTags, ...selected}.toList();
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: nameCtrl,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Nombre de la partida'),
              ),
              const SizedBox(height: 8),
              Text('Etiquetas', style: Theme.of(c).textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 0, children: [
                for (final t in all)
                  FilterChip(
                    label: Text(t),
                    selected: selected.contains(t),
                    onSelected: (v) => set(() => v ? selected.add(t) : selected.remove(t)),
                  ),
              ]),
              TextField(
                controller: tagCtrl,
                decoration: InputDecoration(
                  labelText: 'Nueva etiqueta',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final t = tagCtrl.text.trim().replaceAll(',', ' ');
                      if (t.isNotEmpty) set(() => selected.add(t));
                      tagCtrl.clear();
                    },
                  ),
                ),
              ),
              if (askFormat) ...[
                const SizedBox(height: 16),
                Text('Formato del archivo', style: Theme.of(c).textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<SaveFormat>(
                  segments: [for (final f in SaveFormat.values) ButtonSegment(value: f, label: Text(f.ext.toUpperCase()))],
                  selected: {fmt},
                  onSelectionChanged: (s) => set(() => fmt = s.first),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () {
                final n = nameCtrl.text.trim();
                Navigator.pop(c, SaveInfo(n.isEmpty ? 'Partida sin nombre' : n, selected.toList(), fmt));
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );
}

IconData modeIcon(GameMode m) => m == GameMode.aventura ? Icons.map_outlined : Icons.timer_outlined;
