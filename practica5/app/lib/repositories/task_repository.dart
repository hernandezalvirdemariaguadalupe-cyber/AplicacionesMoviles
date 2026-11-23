import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/api_client.dart';
import '../data/local_db.dart';
import '../data/models.dart';

class TaskSnapshot {
  TaskSnapshot(this.tasks, this.updatedAt, {required this.fromCache, this.elapsed});

  final List<Task> tasks;
  final DateTime? updatedAt;
  final bool fromCache;
  final Duration? elapsed;
}

/// CRUD de tareas de la Práctica 2 (GET, POST, PUT, DELETE) con copia local de lectura.
class TaskRepository {
  TaskRepository(this.api, this.local);

  final ApiClient api;
  final LocalDb local;

  String _metaKey(int userId) => 'tasks_updated:$userId';

  Future<TaskSnapshot> cached(int userId) async {
    final rows = await local.db.query('tasks', where: 'user_id = ?', whereArgs: [userId]);
    final tasks = rows.map((r) => Task.fromJson(jsonDecode(r['json'] as String))).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    final ts = await local.getMeta(_metaKey(userId));
    return TaskSnapshot(tasks, ts == null ? null : DateTime.parse(ts), fromCache: true);
  }

  Future<TaskSnapshot> fetch(int userId) async {
    final sw = Stopwatch()..start();
    final tasks = await api.get('/tasks', (d) => asList(d).map(Task.fromJson).toList());
    sw.stop();
    final now = DateTime.now().toUtc();
    await local.db.transaction((tx) async {
      await tx.delete('tasks', where: 'user_id = ?', whereArgs: [userId]);
      for (final t in tasks) {
        await tx.insert('tasks', {
          'user_id': userId,
          'id': t.id,
          'json': jsonEncode(t.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    await local.setMeta(_metaKey(userId), now.toIso8601String());
    return TaskSnapshot(tasks, now, fromCache: false, elapsed: sw.elapsed);
  }

  Future<Task> create(String title, String? description) =>
      api.post('/tasks', {'title': title, 'description': description}, Task.fromJson);

  Future<Task> update(Task t, {String? title, String? description, bool? completed}) => api.put(
    '/tasks/${t.id}',
    {'title': ?title, 'description': ?description, 'completed': ?completed},
    Task.fromJson,
  );

  Future<void> delete(Task t) => api.delete('/tasks/${t.id}', (_) {});
}
