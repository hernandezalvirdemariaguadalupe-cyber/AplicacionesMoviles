import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../data/local_db.dart';
import '../data/models.dart';

class SyncReport {
  SyncReport({
    required this.sent,
    required this.applied,
    required this.duplicates,
    required this.stale,
    required this.rejected,
  });

  final int sent, applied, duplicates, stale, rejected;

  @override
  String toString() =>
      'enviadas $sent · aplicadas $applied · duplicadas $duplicates · obsoletas $stale · rechazadas $rejected';
}

/// Favoritos e historial: siempre se escribe primero en SQLite (la UI responde al instante,
/// con o sin red) y se encola una operación con op_id único para el servidor.
class LibraryRepository {
  LibraryRepository(this.api, this.local);

  final ApiClient api;
  final LocalDb local;
  static const _uuid = Uuid();

  String _now() => DateTime.now().toUtc().toIso8601String();

  // ---------------- lectura local ----------------

  Future<List<Book>> favorites(int userId) async {
    final rows = await local.db.query(
      'favorites',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => Book.fromJson(jsonDecode(r['json'] as String))).toList();
  }

  Future<bool> isFavorite(int userId, String workKey) async {
    final rows = await local.db.query(
      'favorites',
      columns: ['work_key'],
      where: 'user_id = ? AND work_key = ?',
      whereArgs: [userId, workKey],
    );
    return rows.isNotEmpty;
  }

  Future<List<HistoryEntry>> history(int userId) async {
    final rows = await local.db.query(
      'history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 200,
    );
    return rows
        .map(
          (r) => HistoryEntry(
            clientId: r['client_id'] as String,
            query: r['query'] as String,
            resultsCount: r['results_count'] as int,
            createdAt: DateTime.parse(r['created_at'] as String),
            synced: r['synced'] == 1,
          ),
        )
        .toList();
  }

  Future<int> pendingCount(int userId) async =>
      Sqflite.firstIntValue(
        await local.db.rawQuery('SELECT COUNT(*) FROM pending_ops WHERE user_id = ?', [userId]),
      ) ??
      0;

  // ---------------- escritura local + cola ----------------

  Future<void> _enqueue(
    DatabaseExecutor tx,
    int userId,
    String type,
    String? entityKey,
    Map<String, dynamic> payload,
    String ts,
  ) async {
    // Para favoritos sólo importa la última intención sobre el mismo libro:
    // se compactan las operaciones pendientes anteriores (menos tráfico, sin "parpadeos").
    if (entityKey != null) {
      await tx.delete(
        'pending_ops',
        where: 'user_id = ? AND entity_key = ? AND type IN (?, ?)',
        whereArgs: [userId, entityKey, 'favorite_add', 'favorite_remove'],
      );
    }
    await tx.insert('pending_ops', {
      'user_id': userId,
      'op_id': _uuid.v4(),
      'type': type,
      'entity_key': entityKey,
      'payload': jsonEncode(payload),
      'timestamp': ts,
    });
  }

  Future<void> setFavorite(int userId, Book book, bool favorite) async {
    final ts = _now();
    await local.db.transaction((tx) async {
      if (favorite) {
        await tx.insert('favorites', {
          'user_id': userId,
          'work_key': book.workKey,
          'json': jsonEncode(book.toJson()),
          'updated_at': ts,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _enqueue(tx, userId, 'favorite_add', book.workKey, book.toJson(), ts);
      } else {
        await tx.delete(
          'favorites',
          where: 'user_id = ? AND work_key = ?',
          whereArgs: [userId, book.workKey],
        );
        await _enqueue(tx, userId, 'favorite_remove', book.workKey, {'work_key': book.workKey}, ts);
      }
    });
  }

  Future<void> addHistory(int userId, String query, int resultsCount) async {
    final ts = _now();
    final clientId = _uuid.v4();
    await local.db.transaction((tx) async {
      await tx.insert('history', {
        'user_id': userId,
        'client_id': clientId,
        'query': query,
        'results_count': resultsCount,
        'created_at': ts,
        'synced': 0,
      });
      await _enqueue(tx, userId, 'history_add', null, {
        'client_id': clientId,
        'query': query,
        'results_count': resultsCount,
      }, ts);
    });
  }

  Future<void> clearHistory(int userId) async {
    final ts = _now();
    await local.db.transaction((tx) async {
      await tx.delete('history', where: 'user_id = ?', whereArgs: [userId]);
      await tx.delete('pending_ops', where: 'user_id = ? AND type = ?', whereArgs: [userId, 'history_add']);
      await _enqueue(tx, userId, 'history_clear', null, {}, ts);
    });
  }

  // ---------------- sincronización ----------------

  /// Envía la cola (en orden) y aplica el estado autoritativo del servidor.
  /// Si la respuesta se pierde, el reintento reenvía los mismos op_id y el servidor
  /// responde "duplicate": no hay duplicados ni pérdidas.
  Future<SyncReport> sync(int userId) async {
    final ops = await local.db.query(
      'pending_ops',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'seq ASC',
      limit: 200,
    );
    final body = {
      'operations': ops
          .map(
            (o) => {
              'op_id': o['op_id'],
              'type': o['type'],
              'timestamp': o['timestamp'],
              'payload': jsonDecode(o['payload'] as String),
            },
          )
          .toList(),
    };
    final sentIds = ops.map((o) => o['op_id'] as String).toList();
    if (sentIds.isNotEmpty) {
      await local.db.rawUpdate(
        'UPDATE pending_ops SET attempts = attempts + 1 WHERE op_id IN (${List.filled(sentIds.length, '?').join(',')})',
        sentIds,
      );
    }

    final resp = await api.post('/me/sync', body, asMap);
    final results = asList(resp['results']).map(asMap).toList();
    final serverFavs = asList(resp['favorites']).map(Book.fromJson).toList();
    final serverHistory = asList(resp['history']).map(HistoryEntry.fromServer).toList();
    final favUpdated = {
      for (final f in asList(resp['favorites']).map(asMap)) '${f['work_key']}': '${f['updated_at']}',
    };

    int count(String s) => results.where((r) => r['status'] == s).length;

    await local.db.transaction((tx) async {
      // 1) Sacar de la cola las operaciones que el servidor ya procesó (cualquier estado).
      final done = results.map((r) => r['op_id']).whereType<String>().toList();
      if (done.isNotEmpty) {
        await tx.delete(
          'pending_ops',
          where: 'op_id IN (${List.filled(done.length, '?').join(',')})',
          whereArgs: done,
        );
      }
      for (final r in results.where((r) => r['status'] == 'rejected')) {
        // ignore: avoid_print
        print('Operación rechazada ${r['op_id']}: ${r['error']}');
      }

      // 2) Operaciones que se encolaron mientras viajaba la petición: su intención local gana.
      final stillPending = await tx.query(
        'pending_ops',
        columns: ['type', 'entity_key'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final pendingFavKeys = stillPending
          .where((o) => o['entity_key'] != null)
          .map((o) => o['entity_key'] as String)
          .toSet();
      final pendingHistoryClear = stillPending.any((o) => o['type'] == 'history_clear');

      // 3) Favoritos: el servidor es la fuente de verdad salvo claves con cambios pendientes.
      await tx.delete(
        'favorites',
        where: pendingFavKeys.isEmpty
            ? 'user_id = ?'
            : 'user_id = ? AND work_key NOT IN (${List.filled(pendingFavKeys.length, '?').join(',')})',
        whereArgs: [userId, ...pendingFavKeys],
      );
      for (final b in serverFavs) {
        if (pendingFavKeys.contains(b.workKey)) continue;
        await tx.insert('favorites', {
          'user_id': userId,
          'work_key': b.workKey,
          'json': jsonEncode(b.toJson()),
          'updated_at': favUpdated[b.workKey] ?? _now(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 4) Historial: unión de lo del servidor + entradas locales aún no enviadas.
      if (!pendingHistoryClear) {
        await tx.delete('history', where: 'user_id = ? AND synced = 1', whereArgs: [userId]);
        for (final h in serverHistory) {
          await tx.insert('history', {
            'user_id': userId,
            'client_id': h.clientId,
            'query': h.query,
            'results_count': h.resultsCount,
            'created_at': h.createdAt.toIso8601String(),
            'synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });

    await local.setMeta('last_sync:$userId', DateTime.now().toUtc().toIso8601String());
    return SyncReport(
      sent: ops.length,
      applied: count('applied'),
      duplicates: count('duplicate'),
      stale: count('stale'),
      rejected: count('rejected'),
    );
  }

  Future<DateTime?> lastSync(int userId) async {
    final v = await local.getMeta('last_sync:$userId');
    return v == null ? null : DateTime.parse(v);
  }
}
