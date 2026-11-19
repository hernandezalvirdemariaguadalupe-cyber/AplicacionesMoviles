import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/errors.dart';
import '../core/format.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/native_storage.dart';

// ---------------------------------------------------------------- retroalimentación

void showOk(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

void showError(BuildContext context, Object e, {String action = 'completar la operación'}) {
  final ex = FsException.from(e, action: action);
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: scheme.errorContainer,
      content: Row(children: [
        Icon(_iconFor(ex.kind), color: scheme.onErrorContainer),
        const SizedBox(width: 12),
        Expanded(child: Text(ex.message, style: TextStyle(color: scheme.onErrorContainer))),
      ]),
      duration: const Duration(seconds: 4),
    ));
}

IconData _iconFor(FsErrorKind k) => switch (k) {
      FsErrorKind.permissionDenied => Icons.lock_outline,
      FsErrorKind.notFound => Icons.search_off,
      FsErrorKind.noSpace => Icons.sd_card_alert_outlined,
      FsErrorKind.unsupported => Icons.block,
      _ => Icons.error_outline,
    };

/// Ejecuta [task] mostrando un indicador de progreso modal.
Future<T?> runWithProgress<T>(BuildContext context, String label, Future<T> Function() task,
    {String action = 'completar la operación'}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(label)),
        ]),
      ),
    ),
  );
  try {
    final r = await task();
    nav.pop();
    return r;
  } catch (e) {
    nav.pop();
    if (context.mounted) showError(context, e, action: action);
    return null;
  }
}

// ---------------------------------------------------------------- diálogos

Future<bool> confirm(BuildContext context,
    {required String title, required String message, String ok = 'Aceptar', bool destructive = false}) async {
  final scheme = Theme.of(context).colorScheme;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: destructive ? Icon(Icons.warning_amber_rounded, color: scheme.error) : null,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> askName(BuildContext context, {required String title, String initial = '', String ok = 'Aceptar'}) {
  final ctrl = TextEditingController(text: initial);
  final dot = initial.lastIndexOf('.');
  ctrl.selection = TextSelection(baseOffset: 0, extentOffset: dot > 0 ? dot : initial.length);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: validateFileName,
          onFieldSubmitted: (_) {
            if (formKey.currentState!.validate()) Navigator.pop(c, ctrl.text.trim());
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(c, ctrl.text.trim());
          },
          child: Text(ok),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- acciones del sistema

Future<void> shareEntry(BuildContext context, FsEntry e) async {
  final state = context.read<AppState>();
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final path = await runWithProgress(context, 'Preparando…', () => state.storage.asLocalFile(e), action: 'compartir');
  if (path == null) return;
  try {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path, mimeType: e.effectiveMime, name: e.name)],
      sharePositionOrigin: origin,
    ));
  } catch (err) {
    if (context.mounted) showError(context, err, action: 'compartir');
  }
}

Future<void> exportEntry(BuildContext context, FsEntry e) async {
  try {
    final ref = Platform.isIOS ? await context.read<AppState>().storage.asLocalFile(e) : e.ref;
    final r = await NativeStorage.exportFile(ref, e.name, e.effectiveMime);
    if (!context.mounted) return;
    if (r == null) {
      showOk(context, 'Exportación cancelada');
    } else {
      showOk(context, 'Copia exportada correctamente');
    }
  } catch (err) {
    if (context.mounted) showError(context, err, action: 'exportar');
  }
}

Future<void> openWithEntry(BuildContext context, FsEntry e) async {
  try {
    final ok = await NativeStorage.openWith(e.ref, e.effectiveMime);
    if (!ok && context.mounted) {
      showError(context, const FsException(FsErrorKind.unsupported, 'No hay ninguna app instalada que abra este tipo de archivo.'));
    }
  } catch (err) {
    if (context.mounted) showError(context, err, action: 'abrir con otra aplicación');
  }
}

/// Diálogo para formatos que la app no sabe mostrar.
Future<void> showUnsupportedDialog(BuildContext context, FsEntry e, {VoidCallback? onViewAsText}) {
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.help_outline),
      title: const Text('Formato no soportado'),
      content: Text(
          '“${e.name}” (${e.effectiveMime ?? 'tipo desconocido'}) no se puede visualizar en la app. '
          '¿Qué deseas hacer?'),
      actions: [
        TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir con…'),
            onPressed: () {
              Navigator.pop(c);
              openWithEntry(context, e);
            }),
        TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
            onPressed: () {
              Navigator.pop(c);
              shareEntry(context, e);
            }),
        TextButton.icon(
            icon: const Icon(Icons.save_alt),
            label: const Text('Exportar'),
            onPressed: () {
              Navigator.pop(c);
              exportEntry(context, e);
            }),
        if (onViewAsText != null)
          TextButton.icon(
              icon: const Icon(Icons.text_snippet_outlined),
              label: const Text('Ver como texto'),
              onPressed: () {
                Navigator.pop(c);
                onViewAsText();
              }),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
      ],
    ),
  );
}

/// Hoja con los metadatos disponibles; lo que falte se indica como "No disponible".
Future<void> showMetadata(BuildContext context, FsEntry entry) async {
  final state = context.read<AppState>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => FutureBuilder<FsEntry>(
      future: state.storage.stat(entry.ref),
      builder: (c, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(FsException.from(snap.error!, action: 'leer los metadatos').message),
          );
        }
        final e = snap.data ?? entry;
        final rows = <(String, String)>[
          ('Nombre', e.name),
          ('Tipo', e.isDir ? 'Carpeta' : (e.effectiveMime ?? noDisponible)),
          if (Platform.isIOS) ('UTType', e.utType ?? (e.isDir ? 'public.folder' : noDisponible)),
          ('Tamaño', e.isDir ? '—' : formatSize(e.size)),
          ('Creado', formatDate(e.created)),
          ('Modificado', formatDate(e.modified)),
          ('Origen', e.isSaf ? 'Storage Access Framework' : 'Sistema de archivos local'),
          ('Permisos', [
            if (e.canWrite) 'escritura',
            if (e.canRename) 'renombrar',
            if (e.canDelete) 'eliminar',
            if (e.isDir && e.canCreate) 'crear',
          ].join(', ').ifEmpty('sólo lectura')),
          ('Referencia', e.ref),
        ];
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Información', style: Theme.of(c).textTheme.titleLarge),
              if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              for (final (k, v) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 110, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(
                      child: SelectableText(v,
                          style: TextStyle(
                              color: v == noDisponible ? Theme.of(c).colorScheme.outline : null,
                              fontStyle: v == noDisponible ? FontStyle.italic : null)),
                    ),
                  ]),
                ),
            ]),
          ),
        );
      },
    ),
  );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

IconData iconFor(FsEntry e) {
  if (e.isDir) return Icons.folder_rounded;
  return switch (e.viewer) {
    ViewerKind.image => Icons.image_outlined,
    ViewerKind.json => Icons.data_object,
    ViewerKind.xml => Icons.code,
    ViewerKind.markdown => Icons.article_outlined,
    ViewerKind.text => Icons.description_outlined,
    ViewerKind.unsupported => Icons.insert_drive_file_outlined,
  };
}

Color colorFor(BuildContext context, FsEntry e) {
  if (e.isDir) return const Color(0xFFFFB300);
  return switch (e.viewer) {
    ViewerKind.image => const Color(0xFF43A047),
    ViewerKind.json => const Color(0xFF8E24AA),
    ViewerKind.xml => const Color(0xFFEF6C00),
    ViewerKind.markdown || ViewerKind.text => const Color(0xFF1E88E5),
    ViewerKind.unsupported => Theme.of(context).colorScheme.outline,
  };
}
