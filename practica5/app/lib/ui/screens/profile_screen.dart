import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<HistoryEntry>? _history;
  int _seenVersion = -1;

  Future<void> _load(AppState s) async {
    final h = await s.library.history(s.uid);
    if (mounted) setState(() => _history = h);
  }

  /// Llama a /admin/users aunque la cuenta no sea admin: demuestra que el backend responde 403.
  Future<void> _probeAdmin(AppState s) async {
    try {
      final users = await s.api.get('/admin/users', (d) => (d as List).length);
      if (mounted) showInfo(context, 'Acceso permitido: $users usuarios (HTTP 200)');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user!;
    if (_seenVersion != s.dataVersion) {
      _seenVersion = s.dataVersion;
      _load(s);
    }
    final history = _history ?? [];
    return ListView(
      children: [
        ListTile(
          leading: CircleAvatar(child: Text(u.label.characters.first.toUpperCase())),
          title: Text(u.label, key: const Key('profile_name')),
          subtitle: Text(
            'Usuario: ${u.username} · ID ${u.id}\n'
            'Acceso: ${u.authProvider == 'google' ? 'Google' : 'usuario y contraseña'} · Rol: ${u.role}',
          ),
          isThreeLine: true,
        ),
        ListTile(
          leading: const Icon(Icons.pending_actions),
          title: Text('Cambios pendientes de sincronizar: ${s.pendingOps}', key: const Key('pending_label')),
          subtitle: Text('Última sincronización: ${formatLocal(s.lastSync)}'),
        ),
        if (u.isAdmin)
          ListTile(
            key: const Key('admin_panel_tile'),
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Panel de administrador'),
            subtitle: const Text('Historiales y favoritos de usuarios'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
          ),
        ListTile(
          key: const Key('probe_admin_tile'),
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Probar acceso a /admin/users'),
          subtitle: const Text('Una cuenta sin rol admin recibe HTTP 403 del backend'),
          onTap: () => _probeAdmin(s),
        ),
        const Divider(),
        ListTile(
          title: Text(
            'Historial de búsquedas (${history.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: history.isEmpty
              ? null
              : TextButton(
                  key: const Key('clear_history_button'),
                  onPressed: () async {
                    await s.library.clearHistory(s.uid);
                    await s.localDataChanged();
                  },
                  child: const Text('Borrar'),
                ),
        ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Todavía no hay búsquedas.', key: Key('history_empty')),
          ),
        for (final h in history)
          ListTile(
            dense: true,
            leading: Icon(h.synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined, size: 20),
            title: Text(h.query),
            subtitle: Text(
              '${h.resultsCount} resultados · ${formatLocal(h.createdAt)}'
              '${h.synced ? '' : ' · pendiente'}',
            ),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            key: const Key('logout_button'),
            onPressed: () => s.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}
