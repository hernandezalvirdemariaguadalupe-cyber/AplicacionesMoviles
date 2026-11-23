import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'book_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  SearchPage? _page;
  Object? _error;
  bool _loading = false;
  List<String> _recent = [];
  int _seenVersion = -1;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent(AppState s) async {
    final h = await s.library.history(s.uid);
    if (mounted) setState(() => _recent = h.map((e) => e.query).toSet().take(8).toList());
  }

  Future<void> _search(String q) async {
    final s = context.read<AppState>();
    if (q.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _ctrl.text = q;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await s.books.search(q);
      if (!page.fromCache) {
        await s.library.addHistory(s.uid, page.query, page.total);
        await s.localDataChanged();
      }
      if (mounted) setState(() => _page = page);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = context.watch<AppState>();
    if (_seenVersion != s.dataVersion) {
      _seenVersion = s.dataVersion;
      _loadRecent(s);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            key: const Key('search_field'),
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Título, autor o tema (Open Library)',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                key: const Key('search_button'),
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => _search(_ctrl.text),
              ),
            ),
          ),
        ),
        if (_recent.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final q in _recent)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(q),
                      onPressed: () => _search(q),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView(label: 'Buscando en Open Library…');
    if (_error != null) return ErrorView(error: _error!, onRetry: () => _search(_ctrl.text));
    final page = _page;
    if (page == null) {
      return const EmptyView(
        icon: Icons.travel_explore,
        title: 'Busca un libro',
        subtitle: 'Los resultados se guardan para verlos sin conexión.',
      );
    }
    if (page.books.isEmpty) {
      return EmptyView(
        key: const Key('empty_results'),
        icon: Icons.search_off,
        title: 'Sin resultados para «${page.query}»',
        subtitle: 'Prueba con otras palabras.',
      );
    }
    return Column(
      children: [
        LoadInfo(
          fromCache: page.fromCache,
          elapsed: page.elapsed,
          at: page.fetchedAt,
          extra: '${page.total} encontrados',
        ),
        Expanded(
          child: ListView.separated(
            key: const Key('results_list'),
            itemCount: page.books.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = page.books[i];
              return BookTile(
                book: b,
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailScreen(book: b))),
              );
            },
          ),
        ),
      ],
    );
  }
}
