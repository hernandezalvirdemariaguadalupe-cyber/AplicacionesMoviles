import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'book_detail_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  RecommendationSet? _set;
  bool _loading = false;
  bool _loadedSaved = false;
  Object? _error;

  Future<void> _loadSaved(AppState s) async {
    _loadedSaved = true;
    final saved = await s.recommendations.saved(s.uid);
    if (!mounted) return;
    setState(() => _set = saved);
  }

  Future<void> _generate() async {
    final s = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final set = await s.recommendations.generate(s.uid);
      if (mounted) setState(() => _set = set);
    } catch (e) {
      // Se conservan las recomendaciones guardadas y se informa el error.
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!_loadedSaved) _loadSaved(s);
    final set = _set;
    return ListView(
      key: const Key('recs_list'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: FilledButton.icon(
            key: const Key('generate_recs_button'),
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.auto_awesome),
            label: Text(set == null ? 'Generar recomendaciones' : 'Actualizar recomendaciones'),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Card(
            margin: const EdgeInsets.all(12),
            child: ErrorView(error: _error!, onRetry: _generate),
          ),
        if (set == null && !_loading)
          const EmptyView(
            icon: Icons.auto_awesome_outlined,
            title: 'Sin recomendaciones todavía',
            subtitle:
                'Se calculan con tu historial de búsquedas y tus favoritos. '
                'Si aún no tienes ninguno, se sugieren clásicos populares.',
          ),
        if (set != null) ...[
          Card(
            key: const Key('recs_criteria'),
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    set.coldStart ? 'Sugerencias iniciales' : 'Criterio de recomendación',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(set.criteria),
                  const SizedBox(height: 4),
                  Text(
                    'Generadas: ${formatLocal(set.generatedAt)} · ${set.items.length} libros',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          if (set.items.isEmpty)
            const EmptyView(
              icon: Icons.search_off,
              title: 'No se encontraron libros nuevos con ese criterio',
              subtitle: 'Agrega más favoritos o haz más búsquedas.',
            ),
          for (final r in set.items)
            BookTile(
              book: r.book,
              subtitle: '${r.book.authorsLabel}\n${r.reason}${r.score > 0 ? ' · ${r.score} pts' : ''}',
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => BookDetailScreen(book: r.book))),
            ),
        ],
      ],
    );
  }
}
