import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/app_exception.dart';
import '../../data/models.dart';

final _fmt = DateFormat('dd/MM/yyyy HH:mm:ss');

String formatLocal(DateTime? t) => t == null ? 'nunca' : _fmt.format(t.toLocal());

/// Barra de estado: conexión, sincronización, cola pendiente y última actualización.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, IconData icon) = !s.online
        ? (scheme.errorContainer, Icons.cloud_off)
        : switch (s.syncStatus) {
            SyncStatus.syncing => (scheme.secondaryContainer, Icons.sync),
            SyncStatus.error => (scheme.errorContainer, Icons.sync_problem),
            _ => (scheme.surfaceContainerHigh, Icons.cloud_done),
          };
    final text = !s.online
        ? 'Sin conexión · ${s.pendingOps} cambios en cola · datos guardados'
        : (s.syncMessage ?? 'En línea');
    return Material(
      key: const Key('status_banner'),
      color: bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            s.syncStatus == SyncStatus.syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
                  Text(
                    'Última sincronización: ${formatLocal(s.lastSync)}',
                    key: const Key('last_sync_label'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('sync_button'),
              tooltip: 'Sincronizar',
              onPressed: s.syncStatus == SyncStatus.syncing ? null : () => s.sync(reason: 'manual'),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Cargando…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(label)],
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle!, textAlign: TextAlign.center)],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final e = AppException.from(error);
    return EmptyView(
      key: const Key('error_view'),
      icon: switch (e.kind) {
        ErrorKind.network || ErrorKind.timeout => Icons.wifi_off,
        ErrorKind.forbidden => Icons.lock,
        ErrorKind.malformed => Icons.data_object,
        _ => Icons.error_outline,
      },
      title: e.title,
      subtitle: e.message,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
    );
  }
}

/// "Cargado en 420 ms" o "Copia guardada del dd/MM/yyyy".
class LoadInfo extends StatelessWidget {
  const LoadInfo({super.key, required this.fromCache, this.elapsed, this.at, this.extra});
  final bool fromCache;
  final Duration? elapsed;
  final DateTime? at;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final text = fromCache
        ? 'Copia local guardada el ${formatLocal(at)}'
        : 'Cargado en ${elapsed?.inMilliseconds ?? '?'} ms · ${formatLocal(at)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(fromCache ? Icons.sd_storage : Icons.timer_outlined, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              extra == null ? text : '$text · $extra',
              key: const Key('load_info'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.book, this.size = 'S', this.width = 44, this.height = 64});
  final Book book;
  final String size;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final url = book.coverUrl(size);
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book),
    );
    if (url == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.onTap, this.trailing, this.subtitle});
  final Book book;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('book_${book.workKey}'),
    leading: CoverImage(book: book),
    title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      subtitle ?? '${book.authorsLabel}${book.firstPublishYear != null ? ' · ${book.firstPublishYear}' : ''}',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: trailing,
    onTap: onTap,
  );
}

void showError(BuildContext context, Object error) {
  final e = AppException.from(error);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('${e.title}: ${e.message}')));
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
