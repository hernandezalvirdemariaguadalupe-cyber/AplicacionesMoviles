import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../game/model.dart';
import '../save/codec.dart';
import '../save/native_files.dart';
import '../save/repository.dart';
import 'common.dart';
import 'game_screen.dart';
import 'save_viewer.dart';

/// Gestión de partidas guardadas: lista con metadatos, filtros por formato y
/// etiqueta, cargar, ver contenido, editar etiquetas, convertir, exportar,
/// compartir, importar y eliminar.
class SavesScreen extends StatefulWidget {
  const SavesScreen({super.key});

  @override
  State<SavesScreen> createState() => _SavesScreenState();
}

class _SavesScreenState extends State<SavesScreen> {
  List<SaveEntry>? entries;
  SaveFormat? formatFilter;
  String? tagFilter;

  AppState get app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await app.saves.list();
      if (mounted) setState(() => entries = list);
    } catch (e) {
      if (mounted) {
        setState(() => entries = []);
        snack(context, 'No se pudo leer la carpeta de partidas: $e', error: true);
      }
    }
  }

  List<SaveEntry> get _visible => (entries ?? [])
      .where((e) => formatFilter == null || e.format == formatFilter)
      .where((e) => tagFilter == null || (e.state?.tags.contains(tagFilter) ?? false))
      .toList();

  Set<String> get _allTags => {for (final e in entries ?? <SaveEntry>[]) ...?e.state?.tags};

  // ------------------------------------------------------------------ acciones

  Future<void> _open(SaveEntry e) async {
    final s = e.state;
    if (s == null) return _showCorrupt(e);
    if (s.status != GameStatus.jugando) {
      snack(context, 'Esta partida ya terminó (${s.status.name}). Puedes ver su contenido o su historial.');
      return;
    }
    await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(initial: s)));
  }

  Future<void> _view(SaveEntry e) async {
    final raw = await app.saves.readRaw(e);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SaveViewer(title: e.fileName, content: raw, format: e.format, error: e.error),
      ),
    );
  }

  Future<void> _history(SaveEntry e) async {
    final s = e.state!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (c, scroll) => Column(children: [
          Text('Historial de movimientos (${s.history.length})', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: s.history.isEmpty
                ? const Center(child: Text('Sin movimientos todavía'))
                : ListView.builder(
                    controller: scroll,
                    itemCount: s.history.length,
                    itemBuilder: (_, i) {
                      final h = s.history[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(radius: 16, child: Text(h.dir.label)),
                        title: Text('#${h.n}  (${h.from}) → (${h.to})'),
                        subtitle: Text(h.event.replaceAll('+', ' · ').replaceAll('_', ' ')),
                        trailing: Text(formatDuration(h.tMs)),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Future<void> _editInfo(SaveEntry e) async {
    final s = e.state!;
    final info = await showSaveDialog(context,
        name: s.name, tags: s.tags, format: e.format, askFormat: false, title: 'Nombre y etiquetas');
    if (info == null) return;
    try {
      await app.saves.updateInfo(e, name: info.name, tags: info.tags);
      if (mounted) snack(context, 'Partida actualizada');
      _load();
    } on SaveIoException catch (err) {
      if (mounted) snack(context, err.message, error: true);
    }
  }

  Future<void> _convert(SaveEntry e) async {
    final to = await showDialog<SaveFormat>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Crear copia en otro formato'),
        children: [
          for (final f in SaveFormat.values)
            if (f != e.format)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, f),
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${f.label} (.${f.ext})')),
              ),
        ],
      ),
    );
    if (to == null) return;
    try {
      await app.saves.convert(e, to);
      if (mounted) snack(context, 'Copia creada en ${to.label}');
      _load();
    } on SaveIoException catch (err) {
      if (mounted) snack(context, err.message, error: true);
    }
  }

  Future<void> _export(SaveEntry e) async {
    try {
      final ok = await NativeFiles.export(e.file.path, _exportName(e), e.format.mime);
      if (mounted) snack(context, ok ? 'Partida exportada' : 'Exportación cancelada');
    } on PlatformException catch (err) {
      if (mounted) snack(context, 'No se pudo exportar: ${err.message}', error: true);
    }
  }

  Future<void> _share(SaveEntry e) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(e.file.path, mimeType: e.format.mime)],
        fileNameOverrides: [_exportName(e)],
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (err) {
      if (mounted) snack(context, 'No se pudo compartir: $err', error: true);
    }
  }

  String _exportName(SaveEntry e) {
    final base = (e.state?.name ?? 'partida').replaceAll(RegExp(r'[^\w áéíóúñÁÉÍÓÚÑ-]'), '').trim();
    return '${base.isEmpty ? 'partida' : base}.${e.format.ext}';
  }

  Future<void> _delete(SaveEntry e) async {
    final ok = await confirm(context, '¿Eliminar partida?',
        '“${e.state?.name ?? e.fileName}” se borrará permanentemente. Esta acción no se puede deshacer.',
        ok: 'Eliminar', destructive: true);
    if (!ok) return;
    try {
      await app.saves.delete(e);
      if (mounted) snack(context, 'Partida eliminada');
      _load();
    } on SaveIoException catch (err) {
      if (mounted) snack(context, err.message, error: true);
    }
  }

  Future<void> _import() async {
    try {
      final picked = await NativeFiles.pickFile();
      if (picked == null) {
        if (mounted) snack(context, 'Importación cancelada');
        return;
      }
      final (name, bytes) = picked;
      final s = await app.saves.import(name, bytes);
      if (mounted) snack(context, 'Partida “${s.name}” importada');
      _load();
    } on SaveFormatException catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: Icon(Icons.broken_image_outlined, color: Theme.of(c).colorScheme.error),
            title: const Text('No se pudo importar'),
            content: Text('${e.message}\n\nNo se modificó ninguna de tus partidas.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
          ),
        );
      }
    } on SaveIoException catch (e) {
      if (mounted) snack(context, e.message, error: true);
    } on PlatformException catch (e) {
      if (mounted) snack(context, 'No se pudo abrir el archivo: ${e.message}', error: true);
    }
  }

  Future<void> _showCorrupt(SaveEntry e) async {
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.broken_image_outlined, color: Theme.of(c).colorScheme.error),
        title: const Text('Partida dañada'),
        content: Text('${e.fileName}\n\n${e.error}\n\nTus demás partidas no se ven afectadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'view'), child: const Text('Ver contenido')),
          TextButton(onPressed: () => Navigator.pop(c, 'delete'), child: const Text('Eliminar')),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
        ],
      ),
    );
    if (r == 'view') _view(e);
    if (r == 'delete') _delete(e);
  }

  void _actions(SaveEntry e) {
    if (!e.isValid) {
      _showCorrupt(e);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        Widget t(IconData i, String label, VoidCallback f, {Color? color}) => ListTile(
              leading: Icon(i, color: color),
              title: Text(label, style: TextStyle(color: color)),
              onTap: () {
                Navigator.pop(c);
                f();
              },
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(title: Text(e.state!.name), subtitle: Text('${e.fileName} · ${formatSize(e.size)}')),
              const Divider(height: 1),
              if (e.state!.status == GameStatus.jugando) t(Icons.play_arrow, 'Cargar y continuar', () => _open(e)),
              t(Icons.code, 'Ver contenido del archivo', () => _view(e)),
              t(Icons.timeline, 'Ver historial de movimientos', () => _history(e)),
              t(Icons.label_outline, 'Nombre y etiquetas', () => _editInfo(e)),
              t(Icons.transform, 'Copiar en otro formato', () => _convert(e)),
              t(Icons.save_alt, 'Exportar a una carpeta…', () => _export(e)),
              t(Icons.share, 'Compartir', () => _share(e)),
              t(Icons.delete_outline, 'Eliminar', () => _delete(e), color: Theme.of(c).colorScheme.error),
            ]),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final tags = _allTags.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partidas guardadas'),
        actions: [
          IconButton(tooltip: 'Importar partida', icon: const Icon(Icons.file_open_outlined), onPressed: _import),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(children: [
                      ChoiceChip(
                          label: const Text('Todas'),
                          selected: formatFilter == null && tagFilter == null,
                          onSelected: (_) => setState(() {
                                formatFilter = null;
                                tagFilter = null;
                              })),
                      for (final f in SaveFormat.values)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(f.ext.toUpperCase()),
                            selected: formatFilter == f,
                            onSelected: (v) => setState(() => formatFilter = v ? f : null),
                          ),
                        ),
                      for (final t in tags)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            avatar: const Icon(Icons.label_outline, size: 16),
                            label: Text(t),
                            selected: tagFilter == t,
                            onSelected: (v) => setState(() => tagFilter = v ? t : null),
                          ),
                        ),
                    ]),
                  ),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(entries!.isEmpty ? 'Aún no hay partidas guardadas' : 'Ninguna partida coincide con el filtro',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text('Guarda desde el menú de pausa del juego o importa un archivo.', textAlign: TextAlign.center),
                      ]),
                    ),
                  for (final e in visible) _SaveCard(entry: e, onTap: () => _actions(e)),
                ],
              ),
            ),
    );
  }
}

class _SaveCard extends StatelessWidget {
  const _SaveCard({required this.entry, required this.onTap});
  final SaveEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = entry.state;
    final formatChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(entry.format.ext.toUpperCase(),
          style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.bold, fontSize: 12)),
    );

    if (s == null) {
      return Card(
        color: scheme.errorContainer,
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: ListTile(
          onTap: onTap,
          leading: Icon(Icons.broken_image_outlined, color: scheme.onErrorContainer),
          title: Row(children: [
            Expanded(child: Text(entry.fileName, style: TextStyle(color: scheme.onErrorContainer))),
            formatChip,
          ]),
          subtitle: Text('Archivo dañado: ${entry.error}', style: TextStyle(color: scheme.onErrorContainer)),
        ),
      );
    }

    final status = switch (s.status) {
      GameStatus.jugando => ('En curso', scheme.primary),
      GameStatus.ganada => ('Ganada', Colors.green),
      GameStatus.perdida => ('Perdida', scheme.error),
      GameStatus.terminada => ('Terminada', Colors.orange),
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(modeIcon(s.mode), color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(s.name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
              formatChip,
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 4, children: [
              Text(s.mode == GameMode.aventura ? 'Nivel ${s.level + 1}' : 'Mapa ${s.level}'),
              Text('${s.score} pts'),
              Text('${s.moves} movs'),
              Text('${s.lives} ♥'),
              Text('⏱ ${formatDuration(s.elapsedMs)}'),
              Text(status.$1, style: TextStyle(color: status.$2, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text('${formatDate(s.updatedAt)} · ${formatSize(entry.size)} · ${entry.fileName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline)),
            if (s.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final t in s.tags)
                  Chip(
                    label: Text(t),
                    avatar: const Icon(Icons.label_outline, size: 14),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
