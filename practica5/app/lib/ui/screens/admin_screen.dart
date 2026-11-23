import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/api_client.dart';
import '../../data/models.dart';
import '../widgets/common.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<Map<String, dynamic>>> _future = _fetch();

  Future<List<Map<String, dynamic>>> _fetch() =>
      context.read<AppState>().api.get('/admin/users', (d) => asList(d).map(asMap).toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrador')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _fetch()));
          }
          final users = snap.data!;
          if (users.isEmpty) return const EmptyView(icon: Icons.people_outline, title: 'Sin usuarios');
          return ListView.separated(
            key: const Key('admin_users_list'),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = AppUser.fromJson(users[i]);
              return ListTile(
                leading: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.person),
                title: Text(u.label),
                subtitle: Text(
                  '${u.username} · ${u.role} · ${users[i]['favorites_count']} favoritos · '
                  '${users[i]['history_count']} búsquedas',
                ),
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminUserScreen(user: u))),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminUserScreen extends StatelessWidget {
  const AdminUserScreen({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(user.label),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Historial'),
              Tab(text: 'Favoritos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder(
              future: api.get(
                '/admin/users/${user.id}/history',
                (d) => asList(asMap(d)['history']).map(HistoryEntry.fromServer).toList(),
              ),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) return ErrorView(error: snap.error!);
                final items = snap.data!;
                if (items.isEmpty) return const EmptyView(icon: Icons.history, title: 'Sin búsquedas');
                return ListView(
                  children: [
                    for (final h in items)
                      ListTile(
                        title: Text(h.query),
                        subtitle: Text('${h.resultsCount} resultados · ${formatLocal(h.createdAt)}'),
                      ),
                  ],
                );
              },
            ),
            FutureBuilder(
              future: api.get(
                '/admin/users/${user.id}/favorites',
                (d) => asList(asMap(d)['favorites']).map(Book.fromJson).toList(),
              ),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) return ErrorView(error: snap.error!);
                final items = snap.data!;
                if (items.isEmpty) {
                  return const EmptyView(icon: Icons.favorite_border, title: 'Sin favoritos');
                }
                return ListView(children: [for (final b in items) BookTile(book: b)]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
