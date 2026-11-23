import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'book_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Book>? _items;
  int _seenVersion = -1;

  Future<void> _load(AppState s) async {
    final items = await s.library.favorites(s.uid);
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (_seenVersion != s.dataVersion) {
      _seenVersion = s.dataVersion;
      _load(s);
    }
    final items = _items;
    if (items == null) return const LoadingView();
    return RefreshIndicator(
      onRefresh: () => s.sync(reason: 'manual'),
      child: items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                EmptyView(
                  key: Key('favorites_empty'),
                  icon: Icons.favorite_border,
                  title: 'Aún no tienes favoritos',
                  subtitle: 'Abre un libro y toca el corazón. Funciona también sin conexión.',
                ),
              ],
            )
          : ListView.separated(
              key: const Key('favorites_list'),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = items[i];
                return BookTile(
                  book: b,
                  onTap: () async {
                    await Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => BookDetailScreen(book: b)));
                  },
                  trailing: IconButton(
                    key: Key('unfav_${b.workKey}'),
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () async {
                      await s.library.setFavorite(s.uid, b, false);
                      await s.localDataChanged();
                    },
                  ),
                );
              },
            ),
    );
  }
}
