import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import 'browser_page.dart';
import 'common.dart';
import 'open_entry.dart';
import 'widgets.dart';

/// Pantalla "Explorar": almacenamiento propio + ubicaciones que el usuario autorizó.
class LocationsPage extends StatelessWidget {
  const LocationsPage({super.key});

  Future<void> _openLocation(BuildContext context, StorageLocation loc) async {
    final state = context.read<AppState>();
    if (!loc.available) {
      _unavailable(context, loc);
      return;
    }
    try {
      final root = await state.storage.stat(loc.ref);
      if (!context.mounted) return;
      if (loc.kind == LocationKind.file) {
        await openEntry(context, root, loc.id);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BrowserPage(locationId: loc.id, root: root, rootLabel: loc.name)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      loc.available = false;
      showError(context, e, action: 'abrir la ubicación');
      state.verifyLocations();
    }
  }

  Future<void> _unavailable(BuildContext context, StorageLocation loc) async {
    final state = context.read<AppState>();
    final remove = await confirm(
      context,
      title: 'Ubicación no disponible',
      message: 'Ya no hay acceso a “${loc.name}”: se revocó el permiso, se movió o se eliminó.\n\n'
          'Puedes quitarla de la lista y volver a autorizarla con el selector del sistema.',
      ok: 'Quitar de la lista',
    );
    if (remove) await state.removeLocation(loc);
  }

  /// Explica la finalidad ANTES de abrir el selector del sistema.
  Future<void> _authorize(BuildContext context, {required bool folder}) async {
    final state = context.read<AppState>();
    final go = await confirm(
      context,
      title: folder ? 'Autorizar una carpeta' : 'Abrir archivos',
      message: folder
          ? 'Se abrirá el selector del sistema. La app sólo podrá ver y modificar la carpeta que elijas '
              '(y su contenido), nada más.\n\nPodrás retirar este acceso cuando quieras.'
          : 'Se abrirá el selector del sistema. La app sólo tendrá acceso a los archivos que elijas.',
      ok: 'Continuar',
    );
    if (!go || !context.mounted) return;
    try {
      if (folder) {
        final loc = await state.addFolder();
        if (!context.mounted) return;
        if (loc == null) {
          showOk(context, 'Selección cancelada: no se concedió ningún acceso');
        } else {
          showOk(context, 'Acceso concedido a “${loc.name}”');
          _openLocation(context, loc);
        }
      } else {
        final added = await state.addFiles();
        if (!context.mounted) return;
        if (added.isEmpty) {
          showOk(context, 'Selección cancelada');
        } else if (added.length == 1) {
          _openLocation(context, added.first);
        } else {
          showOk(context, '${added.length} archivos agregados');
        }
      }
    } catch (e) {
      if (context.mounted) showError(context, e, action: 'obtener acceso');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final folders = state.locations.where((l) => l.kind == LocationKind.folder).toList();
    final files = state.locations.where((l) => l.kind == LocationKind.file).toList();
    final scheme = Theme.of(context).colorScheme;

    Widget locTile(StorageLocation l) => ListTile(
          leading: Icon(
            l.kind == LocationKind.folder ? Icons.folder_shared_outlined : Icons.insert_drive_file_outlined,
            color: l.available ? scheme.primary : scheme.outline,
          ),
          title: Text(l.name, overflow: TextOverflow.ellipsis),
          subtitle: Text(l.available ? (Platform.isAndroid ? 'Storage Access Framework' : 'Archivos (security-scoped)') : 'No disponible · toca para resolver',
              style: TextStyle(color: l.available ? null : scheme.error)),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'remove') {
                final ok = await confirm(context,
                    title: 'Quitar acceso',
                    message: 'La app dejará de tener acceso a “${l.name}”. Los archivos NO se eliminan.',
                    ok: 'Quitar');
                if (ok) await state.removeLocation(l);
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Quitar acceso'))],
          ),
          onTap: () => _openLocation(context, l),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Gestor de Archivos')),
      body: RefreshIndicator(
        onRefresh: state.verifyLocations,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                color: scheme.primaryContainer,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(Icons.phone_android, color: scheme.onPrimaryContainer, size: 36),
                  title: Text(state.appLocation.name,
                      style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                  subtitle: Text('Espacio privado de la aplicación', style: TextStyle(color: scheme.onPrimaryContainer)),
                  trailing: Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
                  onTap: () => _openLocation(context, state.appLocation),
                ),
              ),
            ),
            _header(context, 'Carpetas autorizadas'),
            if (folders.isEmpty)
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Aún no has autorizado ninguna carpeta'),
                subtitle: Text('La app no tiene acceso al resto del almacenamiento hasta que tú lo decidas.'),
              ),
            ...folders.map(locTile),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonalIcon(
                  onPressed: () => _authorize(context, folder: true),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Autorizar carpeta'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _authorize(context, folder: false),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Abrir archivo'),
                ),
              ]),
            ),
            if (files.isNotEmpty) ...[
              _header(context, 'Archivos autorizados'),
              ...files.map(locTile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

/// Lista de Recientes o Favoritos.
class SavedListPage extends StatelessWidget {
  const SavedListPage({super.key, required this.favorites});
  final bool favorites;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = favorites ? state.favorites : state.recents;
    return Scaffold(
      appBar: AppBar(
        title: Text(favorites ? 'Favoritos' : 'Recientes'),
        actions: [
          if (!favorites && list.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar historial',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                if (await confirm(context, title: 'Limpiar recientes', message: '¿Borrar el historial? Los archivos no se eliminan.', ok: 'Limpiar')) {
                  state.clearRecents();
                }
              },
            ),
        ],
      ),
      body: list.isEmpty
          ? EmptyState(
              icon: favorites ? Icons.star_border : Icons.history,
              title: favorites ? 'Sin favoritos' : 'Sin archivos recientes',
              message: favorites
                  ? 'Mantén presionado un archivo o carpeta y elige “Agregar a favoritos”.'
                  : 'Los archivos que abras aparecerán aquí, incluso después de cerrar la app.',
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final r = list[i];
                final loc = state.locationById(r.locationId);
                final entry = FsEntry(ref: r.ref, name: r.name, isDir: r.isDir);
                void remove() => favorites ? state.removeFavorite(r.ref) : state.removeRecent(r.ref);
                return Dismissible(
                  key: ValueKey(r.ref),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.remove_circle_outline),
                  ),
                  onDismissed: (_) => remove(),
                  child: ListTile(
                    leading: Icon(iconFor(entry), color: colorFor(context, entry)),
                    title: Text(r.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${loc?.name ?? 'Ubicación eliminada'} · ${_ago(r.at)}'),
                    onTap: () => openSaved(context, r, onMissing: remove),
                  ),
                );
              },
            ),
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }
}
