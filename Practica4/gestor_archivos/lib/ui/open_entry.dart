import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import 'browser_page.dart';
import 'common.dart';
import 'viewers/document_viewer.dart';
import 'viewers/image_viewer.dart';

/// Abre un archivo con el visor adecuado (o el diálogo de formato no soportado)
/// y lo registra en Recientes.
Future<void> openEntry(BuildContext context, FsEntry e, String locationId) async {
  final state = context.read<AppState>();
  if (e.isDir) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowserPage(locationId: locationId, root: e),
      ),
    );
    return;
  }
  state.addRecent(e, locationId);
  final Widget? page = switch (e.viewer) {
    ViewerKind.image => ImageViewer(entry: e),
    ViewerKind.unsupported => null,
    _ => DocumentViewer(entry: e),
  };
  if (page == null) {
    await showUnsupportedDialog(
      context,
      e,
      onViewAsText: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewer(entry: e, forceKind: ViewerKind.text)),
      ),
    );
    return;
  }
  await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

/// Abre un elemento guardado (recientes/favoritos) comprobando antes que siga existiendo.
Future<void> openSaved(BuildContext context, SavedRef r, {required VoidCallback onMissing}) async {
  final state = context.read<AppState>();
  final loc = state.locationById(r.locationId);
  if (loc != null && !loc.available) {
    showError(context, Exception('La ubicación “${loc.name}” ya no está autorizada. Vuelve a autorizarla.'));
    return;
  }
  try {
    final e = await state.storage.stat(r.ref);
    if (context.mounted) await openEntry(context, e, r.locationId);
  } catch (err) {
    if (!context.mounted) return;
    final remove = await confirm(context,
        title: 'Elemento no disponible',
        message: '“${r.name}” ya no existe, se movió o se revocó el permiso.\n\n¿Quitarlo de la lista?',
        ok: 'Quitar');
    if (remove) onMissing();
  }
}
