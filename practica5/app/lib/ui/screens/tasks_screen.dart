import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../data/models.dart';
import '../../repositories/task_repository.dart';
import '../widgets/common.dart';

/// CRUD de la Práctica 2 (GET/POST/PUT/DELETE /tasks). Sin red se muestran las tareas guardadas
/// en modo sólo lectura; crear/editar/borrar requiere al servidor.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskSnapshot? _snap;
  Object? _error;
  bool _loading = false;
  bool _started = false;

  Future<void> _load() async {
    final s = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await s.tasks.fetch(s.uid);
      if (mounted) setState(() => _snap = snap);
    } catch (e) {
      final cached = await s.tasks.cached(s.uid);
      if (mounted) {
        setState(() {
          _error = e;
          if (cached.updatedAt != null) _snap = cached;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mutate(Future<void> Function() action, String ok) async {
    final s = context.read<AppState>();
    if (!s.online) {
      showInfo(context, 'Sin conexión: editar tareas requiere al servidor.');
      return;
    }
    try {
      await action();
      if (mounted) showInfo(context, ok);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _edit([Task? task]) async {
    final title = TextEditingController(text: task?.title);
    final desc = TextEditingController(text: task?.description);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(task == null ? 'Nueva tarea' : 'Editar tarea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('task_title_field'),
              controller: title,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('task_save_button'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != true || title.text.trim().isEmpty || !mounted) return;
    final s = context.read<AppState>();
    await _mutate(
      () => task == null
          ? s.tasks.create(title.text.trim(), desc.text.trim())
          : s.tasks.update(task, title: title.text.trim(), description: desc.text.trim()),
      task == null ? 'Tarea creada (POST)' : 'Tarea actualizada (PUT)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final snap = _snap;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const Key('add_task_button'),
        onPressed: s.online ? () => _edit() : null,
        tooltip: 'Nueva tarea',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (snap != null)
              LoadInfo(
                fromCache: snap.fromCache,
                elapsed: snap.elapsed,
                at: snap.updatedAt,
                extra: 'GET /tasks · ${snap.tasks.length} tareas',
              ),
            if (_error != null)
              snap == null
                  ? ErrorView(error: _error!, onRetry: _load)
                  : ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(
                        'Mostrando copia local: ${(_error is Exception) ? _error.toString() : 'error'}',
                      ),
                    ),
            if (snap != null && snap.tasks.isEmpty)
              const EmptyView(
                key: Key('tasks_empty'),
                icon: Icons.checklist,
                title: 'No hay tareas',
                subtitle: 'Crea una con el botón +',
              ),
            if (snap != null)
              for (final t in snap.tasks)
                ListTile(
                  key: Key('task_${t.id}'),
                  leading: Checkbox(
                    value: t.completed,
                    onChanged: (v) =>
                        _mutate(() => s.tasks.update(t, completed: v ?? false), 'Tarea actualizada (PUT)'),
                  ),
                  title: Text(
                    t.title,
                    style: t.completed ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                  ),
                  subtitle: (t.description ?? '').isEmpty ? null : Text(t.description!),
                  onTap: () => _edit(t),
                  trailing: IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _mutate(() => s.tasks.delete(t), 'Tarea eliminada (DELETE)'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
