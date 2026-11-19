import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../common.dart';
import 'syntax.dart';

/// Visor/editor para TXT, MD, JSON y XML.
class DocumentViewer extends StatefulWidget {
  const DocumentViewer({super.key, required this.entry, this.forceKind});
  final FsEntry entry;
  final ViewerKind? forceKind;

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  static const _maxBytes = 2 * 1024 * 1024; // 2 MB
  static const _maxHighlight = 300 * 1024;

  late FsEntry entry = widget.entry;
  late final ViewerKind kind = widget.forceKind ?? entry.viewer;
  String? raw;
  Object? error;
  bool truncated = false;
  bool pretty = true;
  bool wrap = true;
  bool editing = false;
  bool dirty = false;
  double fontSize = 14;
  final editor = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      raw = null;
    });
    try {
      final storage = context.read<AppState>().storage;
      entry = await storage.stat(entry.ref);
      final bytes = await storage.read(entry.ref, maxBytes: _maxBytes + 1);
      truncated = bytes.length > _maxBytes;
      final text = utf8.decode(truncated ? bytes.sublist(0, _maxBytes) : bytes, allowMalformed: true);
      if (!mounted) return;
      setState(() => raw = text);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Formatted get _formatted {
    final text = raw ?? '';
    if (!pretty || editing) return Formatted(text, null);
    return switch (kind) {
      ViewerKind.json => Syntax.prettyJson(text),
      ViewerKind.xml => Syntax.prettyXml(text),
      _ => Formatted(text, null),
    };
  }

  bool get _canEdit => entry.canWrite && !truncated && raw != null;

  Future<void> _save() async {
    final text = editor.text;
    String? problem;
    if (kind == ViewerKind.json) problem = Syntax.prettyJson(text).error;
    if (kind == ViewerKind.xml) problem = Syntax.prettyXml(text).error;
    if (problem != null) {
      final go = await confirm(context,
          title: 'Contenido no válido', message: '$problem\n\n¿Guardar de todas formas?', ok: 'Guardar');
      if (!go || !mounted) return;
    }
    final state = context.read<AppState>();
    final ok = await runWithProgress(context, 'Guardando…', () async {
      await state.storage.overwrite(entry, utf8.encode(text));
      return true;
    }, action: 'guardar el archivo');
    if (ok == true && mounted) {
      setState(() {
        raw = text;
        editing = false;
        dirty = false;
      });
      showOk(context, 'Archivo guardado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mono = TextStyle(fontFamily: 'monospace', fontSize: fontSize, height: 1.4);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context,
            title: 'Cambios sin guardar', message: '¿Salir y descartar los cambios?', ok: 'Descartar', destructive: true);
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(entry.name, overflow: TextOverflow.ellipsis),
          actions: [
            if (editing)
              IconButton(tooltip: 'Guardar', icon: const Icon(Icons.save), onPressed: _save)
            else ...[
              if (kind == ViewerKind.json || kind == ViewerKind.xml)
                IconButton(
                  tooltip: pretty ? 'Ver original' : 'Ver formateado',
                  icon: Icon(pretty ? Icons.notes : Icons.auto_fix_high),
                  onPressed: () => setState(() => pretty = !pretty),
                ),
              if (_canEdit)
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit),
                  onPressed: () => setState(() {
                    editor.text = _formatted.error == null ? _formatted.text : raw!;
                    editing = true;
                  }),
                ),
            ],
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'wrap':
                    setState(() => wrap = !wrap);
                  case 'bigger':
                    setState(() => fontSize = (fontSize + 2).clamp(10, 30));
                  case 'smaller':
                    setState(() => fontSize = (fontSize - 2).clamp(10, 30));
                  case 'info':
                    showMetadata(context, entry);
                  case 'share':
                    shareEntry(context, entry);
                  case 'export':
                    exportEntry(context, entry);
                }
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(value: 'wrap', checked: wrap, child: const Text('Ajustar líneas')),
                const PopupMenuItem(value: 'bigger', child: Text('Texto más grande')),
                const PopupMenuItem(value: 'smaller', child: Text('Texto más pequeño')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'info', child: Text('Información')),
                const PopupMenuItem(value: 'share', child: Text('Compartir')),
                const PopupMenuItem(value: 'export', child: Text('Exportar copia')),
              ],
            ),
          ],
        ),
        body: _body(mono),
      ),
    );
  }

  Widget _body(TextStyle mono) {
    if (error != null) {
      final ex = FsException.from(error!, action: 'leer el archivo');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(ex.message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ]),
        ),
      );
    }
    if (raw == null) return const Center(child: CircularProgressIndicator());

    if (editing) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: editor,
          maxLines: null,
          expands: true,
          style: mono,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (_) {
            if (!dirty) setState(() => dirty = true);
          },
        ),
      );
    }

    final f = _formatted;
    final colors = SyntaxColors.of(context);
    final highlight = f.text.length <= _maxHighlight;
    final spans = !highlight
        ? [TextSpan(text: f.text)]
        : switch (kind) {
            ViewerKind.json when f.error == null => Syntax.json(f.text, colors),
            ViewerKind.xml => Syntax.xml(f.text, colors),
            ViewerKind.markdown => Syntax.markdown(f.text, colors),
            _ => [TextSpan(text: f.text)],
          };
    final lines = '\n'.allMatches(f.text).length + 1;
    final scheme = Theme.of(context).colorScheme;

    final text = Padding(
      padding: const EdgeInsets.all(12),
      child: SelectableText.rich(
        TextSpan(style: mono.copyWith(color: colors.plain), children: spans),
      ),
    );
    final content = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Números de línea
      Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Text(
          List.generate(lines, (i) => '${i + 1}').join('\n'),
          textAlign: TextAlign.right,
          style: mono.copyWith(color: scheme.outline),
        ),
      ),
      if (wrap) Expanded(child: text) else text,
    ]);

    return Column(children: [
      if (f.error != null)
        MaterialBanner(
          leading: const Icon(Icons.warning_amber_rounded),
          content: Text('${f.error}\nSe muestra el contenido original.'),
          actions: const [SizedBox.shrink()],
        ),
      if (truncated)
        const MaterialBanner(
          leading: Icon(Icons.info_outline),
          content: Text('Archivo grande: se muestran sólo los primeros 2 MB (edición deshabilitada).'),
          actions: [SizedBox.shrink()],
        ),
      if (!highlight)
        const MaterialBanner(
          content: Text('Resaltado desactivado por el tamaño del archivo.'),
          actions: [SizedBox.shrink()],
        ),
      Expanded(
        child: SingleChildScrollView(
          child: wrap
              ? content
              : SingleChildScrollView(scrollDirection: Axis.horizontal, child: content),
        ),
      ),
    ]);
  }
}
