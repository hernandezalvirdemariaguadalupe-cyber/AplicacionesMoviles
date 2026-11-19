import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'common.dart';

/// Ruta de navegación (breadcrumbs). Cada segmento es tocable para regresar a ese nivel.
class Breadcrumbs extends StatefulWidget {
  const Breadcrumbs({super.key, required this.segments, required this.onTap});
  final List<String> segments;
  final ValueChanged<int> onTap;

  @override
  State<Breadcrumbs> createState() => _BreadcrumbsState();
}

class _BreadcrumbsState extends State<Breadcrumbs> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant Breadcrumbs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Siempre muestra el final de la ruta (carpeta actual).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      color: scheme.surfaceContainerHigh,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: widget.segments.length,
        separatorBuilder: (_, _) => Icon(Icons.chevron_right, size: 18, color: scheme.outline),
        itemBuilder: (_, i) {
          final last = i == widget.segments.length - 1;
          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: last ? null : () => widget.onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (i == 0) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.home_outlined, size: 18, color: scheme.primary)),
                  Text(
                    widget.segments[i],
                    style: TextStyle(
                      fontWeight: last ? FontWeight.bold : FontWeight.normal,
                      color: last ? scheme.onSurface : scheme.primary,
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Icono del archivo o miniatura (si es imagen) obtenida de la caché.
class EntryThumb extends StatefulWidget {
  const EntryThumb({super.key, required this.entry, this.size = 40});
  final FsEntry entry;
  final double size;

  @override
  State<EntryThumb> createState() => _EntryThumbState();
}

class _EntryThumbState extends State<EntryThumb> {
  Uint8List? thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EntryThumb old) {
    super.didUpdateWidget(old);
    if (old.entry.ref != widget.entry.ref || old.entry.modified != widget.entry.modified) {
      thumb = null;
      _load();
    }
  }

  void _load() {
    if (widget.entry.viewer != ViewerKind.image) return;
    final cache = context.read<AppState>().thumbnails;
    thumb = cache.peek(widget.entry);
    if (thumb == null) {
      cache.get(widget.entry).then((v) {
        if (mounted && v != null) setState(() => thumb = v);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    if (thumb != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(thumb!, width: s, height: s, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }
    return SizedBox(
      width: s,
      height: s,
      child: Icon(iconFor(widget.entry), size: s * 0.8, color: colorFor(context, widget.entry)),
    );
  }
}

String subtitleFor(FsEntry e) {
  if (e.isDir) return formatDate(e.modified) == noDisponible ? 'Carpeta' : 'Carpeta · ${formatDate(e.modified)}';
  return '${formatSize(e.size)} · ${formatDate(e.modified)}';
}

/// Estado vacío o de error reutilizable.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: scheme.outline)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}
