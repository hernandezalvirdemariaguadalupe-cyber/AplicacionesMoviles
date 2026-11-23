import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';

class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({super.key, required this.book});
  final Book book;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late Book _book = widget.book;
  bool _loading = true;
  bool _fromCache = false;
  bool _favorite = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    _favorite = await s.library.isFavorite(s.uid, widget.book.workKey);
    try {
      final (book, cached) = await s.books.detail(widget.book);
      if (mounted) {
        setState(() {
          _book = book;
          _fromCache = cached;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final s = context.read<AppState>();
    final next = !_favorite;
    setState(() => _favorite = next);
    await s.books.saveBook(_book);
    await s.library.setFavorite(s.uid, _book, next);
    await s.localDataChanged();
    if (mounted) {
      showInfo(
        context,
        '${next ? 'Agregado a' : 'Quitado de'} favoritos${s.online ? '' : ' (se sincronizará al reconectar)'}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _book;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          IconButton(
            key: const Key('favorite_button'),
            tooltip: _favorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
            onPressed: _toggleFavorite,
            icon: Icon(
              _favorite ? Icons.favorite : Icons.favorite_border,
              color: _favorite ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(book: b, size: 'M', width: 110, height: 165),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      key: const Key('detail_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(b.authorsLabel),
                    if (b.firstPublishYear != null) Text('Primera publicación: ${b.firstPublishYear}'),
                    if (b.editionCount > 0) Text('Ediciones: ${b.editionCount}'),
                    Text('Clave: ${b.workKey}', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_fromCache)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Mostrando la copia guardada (sin conexión).'),
            ),
          if (_error != null) ErrorView(error: _error!, onRetry: _load),
          if (b.description != null && b.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(b.description!),
          ],
          if (b.subjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Temas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in b.subjects.take(15))
                  Chip(label: Text(t), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
