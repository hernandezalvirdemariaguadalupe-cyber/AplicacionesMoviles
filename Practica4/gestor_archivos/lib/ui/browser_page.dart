import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'common.dart';
import 'open_entry.dart';
import 'widgets.dart';

/// Explorador de una ubicación autorizada. Mantiene su propia pila de carpetas para
/// mostrar breadcrumbs y nunca sube por encima de la raíz autorizada.
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, required this.locationId, required this.root, this.rootLabel});
  final String locationId;
  final FsEntry root;
  final String? rootLabel;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final List<FsEntry> stack = [widget.root];
  List<FsEntry>? items;
  Object? error;
  String filter = '';
  bool searching = false;

  AppState get state => context.read<AppState>();
  FsEntry get current => stack.last;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => error = null);
    try {
      final list = await state.storage.list(current.ref);
      if (mounted) setState(() => items = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          items = null;
        });
      }
    }
  }

  void _enter(FsEntry dir) {
    setState(() {
      stack.add(dir);
      items = null;
      filter = '';
    });
    _refresh();
  }

  void _goTo(int index) {
    setState(() {
      stack.removeRange(index + 1, stack.length);
      items = null;
    });
    _refresh();
  }

  // ------------------------------------------------------------------ acciones

  Future<void> _newFolder() async {
    final name = await askName(context, title: 'Nueva carpeta', initial: 'Nueva carpeta', ok: 'Crear');
    if (name == null || !mounted) return;
    final r = await runWithProgress(context, 'Creando carpeta…', () => state.storage.createDirectory(current, name),
        action: 'crear la carpeta');
    if (r != null && mounted) {
      showOk(context, 'Carpeta “$name” creada');
      _refresh();
    }
  }

  Future<void> _newTextFile() async {
    var name = await askName(context, title: 'Nuevo archivo de texto', initial: 'nota.txt', ok: 'Crear');
    if (name == null || !mounted) return;
    if (!name.contains('.')) name = '$name.txt';
    final finalName = name;
    final r = await runWithProgress(
      context,
      'Creando archivo…',
      () => state.storage.createFile(current, finalName, Uint8List(0), mime: 'text/plain'),
      action: 'crear el archivo',
    );
    if (r != null && mounted) {
      await _refresh();
      if (!mounted) return;
      final created = items?.where((e) => e.name == finalName).firstOrNull;
      if (created != null) openEntry(context, created, widget.locationId).then((_) => _refresh());
    }
  }

  Future<void> _rename(FsEntry e) async {
    final name = await askName(context, title: 'Renombrar', initial: e.name, ok: 'Renombrar');
    if (name == null || name == e.name || !mounted) return;
    final newRef = await runWithProgress(
        context, 'Renombrando…', () => state.storage.rename(e, name, parentRef: current.ref),
        action: 'renombrar');
    if (newRef != null && mounted) {
      await state.refChanged(e.ref, newRef, newName: name);
      if (mounted) showOk(context, 'Renombrado a “$name”');
      _refresh();
    }
  }

  Future<void> _delete(FsEntry e) async {
    if (!e.canDelete) {
      showError(context,
          const FsException(FsErrorKind.permissionDenied, 'El proveedor de documentos no permite eliminar este elemento.'));
      return;
    }
    final ok = await confirm(
      context,
      title: '¿Eliminar “${e.name}”?',
      message: e.isDir
          ? 'Se eliminará la carpeta y TODO su contenido. Esta acción no se puede deshacer.'
          : 'El archivo se eliminará permanentemente. Esta acción no se puede deshacer.',
      ok: 'Eliminar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await runWithProgress(context, 'Eliminando…', () async {
      await state.storage.delete(e);
      return true;
    }, action: 'eliminar');
    if (done == true && mounted) {
      await state.refChanged(e.ref, null);
      if (state.clipboard?.entry.ref == e.ref) state.clearClipboard();
      if (mounted) showOk(context, '“${e.name}” eliminado');
      _refresh();
    }
  }

  Future<void> _paste() async {
    final op = state.clipboard!;
    if (!current.canCreate) {
      showError(context, const FsException(FsErrorKind.permissionDenied, 'Esta carpeta es de sólo lectura.'));
      return;
    }
    final r = await runWithProgress(context, op.move ? 'Moviendo…' : 'Copiando…', () => state.paste(current),
        action: op.move ? 'mover' : 'copiar');
    if (r != null && mounted) {
      showOk(context, op.move ? 'Elemento movido' : 'Elemento copiado');
      _refresh();
    }
  }

  void _showActions(FsEntry e) {
    final fav = state.isFavorite(e.ref);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) {
        Widget tile(IconData i, String t, VoidCallback onTap, {bool enabled = true, Color? color}) => ListTile(
              leading: Icon(i, color: enabled ? color : null),
              title: Text(t, style: TextStyle(color: enabled ? color : null)),
              enabled: enabled,
              onTap: () {
                Navigator.pop(c);
                onTap();
              },
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: EntryThumb(entry: e),
                title: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(subtitleFor(e)),
              ),
              const Divider(height: 1),
              tile(Icons.open_in_full, 'Abrir', () => _open(e)),
              tile(Icons.info_outline, 'Información', () => showMetadata(context, e)),
              tile(fav ? Icons.star : Icons.star_border, fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
                  () => state.toggleFavorite(e, widget.locationId)),
              tile(Icons.drive_file_rename_outline, 'Renombrar', () => _rename(e), enabled: e.canRename),
              tile(Icons.copy, 'Copiar', () {
                state.setClipboard(e, move: false);
                showOk(context, 'Navega a la carpeta destino y toca “Pegar aquí”');
              }),
              tile(Icons.drive_file_move_outline, 'Mover', () {
                state.setClipboard(e, move: true);
                showOk(context, 'Navega a la carpeta destino y toca “Pegar aquí”');
              }, enabled: e.canDelete),
              if (!e.isDir) ...[
                tile(Icons.share, 'Compartir', () => shareEntry(context, e)),
                tile(Icons.open_in_new, 'Abrir con otra app', () => openWithEntry(context, e)),
                tile(Icons.save_alt, 'Exportar copia…', () => exportEntry(context, e)),
              ],
              tile(Icons.delete_outline, 'Eliminar', () => _delete(e),
                  enabled: e.canDelete, color: Theme.of(context).colorScheme.error),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _open(FsEntry e) async {
    if (e.isDir) {
      _enter(e);
      return;
    }
    await openEntry(context, e, widget.locationId);
    if (mounted) _refresh(); // por si se editó
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final segments = [widget.rootLabel ?? widget.root.name, ...stack.skip(1).map((e) => e.name)];
    final visible = items?.where((e) => filter.isEmpty || e.name.toLowerCase().contains(filter.toLowerCase())).toList();

    return PopScope(
      canPop: stack.length == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(stack.length - 2);
      },
      child: Scaffold(
        appBar: AppBar(
          title: searching
              ? TextField(
                  autofocus: true,
                  style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor),
                  cursorColor: Theme.of(context).appBarTheme.foregroundColor,
                  decoration: InputDecoration(
                    hintText: 'Filtrar en esta carpeta',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor?.withValues(alpha: 0.7)),
                  ),
                  onChanged: (v) => setState(() => filter = v),
                )
              : Text(segments.last, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: searching ? 'Cerrar búsqueda' : 'Buscar',
              icon: Icon(searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                searching = !searching;
                filter = '';
              }),
            ),
            IconButton(
              tooltip: app.gridView ? 'Vista de lista' : 'Vista de cuadrícula',
              icon: Icon(app.gridView ? Icons.view_list : Icons.grid_view),
              onPressed: app.toggleGrid,
            ),
            IconButton(
              tooltip: 'Información de la carpeta',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showMetadata(context, current),
            ),
          ],
        ),
        body: Column(children: [
          Breadcrumbs(segments: segments, onTap: _goTo),
          Expanded(child: _content(app, visible)),
          if (app.clipboard != null) _clipboardBar(app.clipboard!),
        ]),
        floatingActionButton: error == null
            ? FloatingActionButton(
                tooltip: 'Nuevo',
                onPressed: !current.canCreate
                    ? () => showError(context,
                        const FsException(FsErrorKind.permissionDenied, 'Esta carpeta es de sólo lectura.'))
                    : () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (c) => SafeArea(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              ListTile(
                                leading: const Icon(Icons.create_new_folder_outlined),
                                title: const Text('Nueva carpeta'),
                                onTap: () {
                                  Navigator.pop(c);
                                  _newFolder();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.note_add_outlined),
                                title: const Text('Nuevo archivo de texto'),
                                onTap: () {
                                  Navigator.pop(c);
                                  _newTextFile();
                                },
                              ),
                            ]),
                          ),
                        ),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _clipboardBar(ClipboardOp op) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(children: [
            Icon(op.move ? Icons.drive_file_move_outline : Icons.copy, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${op.move ? 'Mover' : 'Copiar'}: ${op.entry.name}',
                  overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSecondaryContainer)),
            ),
            TextButton(onPressed: context.read<AppState>().clearClipboard, child: const Text('Cancelar')),
            FilledButton(onPressed: _paste, child: const Text('Pegar aquí')),
          ]),
        ),
      ),
    );
  }

  Widget _content(AppState app, List<FsEntry>? visible) {
    if (error != null) {
      final ex = FsException.from(error!, action: 'leer la carpeta');
      return EmptyState(
        icon: ex.kind == FsErrorKind.permissionDenied ? Icons.lock_outline : Icons.folder_off_outlined,
        title: ex.message,
        message: ex.kind == FsErrorKind.permissionDenied
            ? 'Puedes volver a autorizar la carpeta desde la pantalla Explorar.'
            : null,
        action: OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      );
    }
    if (visible == null) return const Center(child: CircularProgressIndicator());
    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.folder_open,
            title: filter.isEmpty ? 'Carpeta vacía' : 'Sin coincidencias',
            message: filter.isEmpty ? 'Usa el botón + para crear contenido.' : null,
          ),
        ]),
      );
    }

    if (app.gridView) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.85,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: visible.length,
          itemBuilder: (_, i) {
            final e = visible[i];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _open(e),
              onLongPress: () => _showActions(e),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(children: [
                  Expanded(child: Center(child: EntryThumb(entry: e, size: 72))),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (app.isFavorite(e.ref)) const Icon(Icons.star, size: 14, color: Color(0xFFD4AF37)),
                    Flexible(
                      child: Text(e.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ]),
                ]),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: visible.length,
        itemBuilder: (_, i) {
          final e = visible[i];
          return ListTile(
            leading: EntryThumb(entry: e),
            title: Row(children: [
              Flexible(child: Text(e.name, overflow: TextOverflow.ellipsis)),
              if (app.isFavorite(e.ref))
                const Padding(
                    padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 16, color: Color(0xFFD4AF37))),
            ]),
            subtitle: Text(subtitleFor(e)),
            trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showActions(e)),
            onTap: () => _open(e),
            onLongPress: () => _showActions(e),
          );
        },
      ),
    );
  }
}
