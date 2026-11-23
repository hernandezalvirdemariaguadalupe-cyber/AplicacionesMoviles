import 'dart:convert';
import 'dart:typed_data';

import 'package:biblioteca_app/core/api_client.dart';
import 'package:biblioteca_app/data/local_db.dart';
import 'package:biblioteca_app/data/models.dart';
import 'package:biblioteca_app/repositories/library_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Servidor falso que imita /me/sync (idempotente por op_id).
class FakeSyncAdapter implements HttpClientAdapter {
  final applied = <String>{};
  final favorites = <String, Map<String, dynamic>>{};
  final requests = <List<dynamic>>[];
  bool failNext = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ops = (options.data as Map)['operations'] as List;
    requests.add(ops);
    final results = [];
    for (final op in ops) {
      final id = op['op_id'] as String;
      if (!applied.add(id)) {
        results.add({'op_id': id, 'status': 'duplicate'});
        continue;
      }
      final p = op['payload'] as Map;
      if (op['type'] == 'favorite_add') {
        favorites[p['work_key'] as String] = {...p.cast<String, dynamic>(), 'updated_at': op['timestamp']};
      } else if (op['type'] == 'favorite_remove') {
        favorites.remove(p['work_key']);
      }
      results.add({'op_id': id, 'status': 'applied'});
    }
    if (failNext) {
      failNext = false;
      // El servidor aplicó todo pero la respuesta "se perdió" en el camino.
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(
      jsonEncode({'results': results, 'favorites': favorites.values.toList(), 'history': []}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  sqfliteFfiInit();
  late LocalDb db;
  late LibraryRepository repo;
  late FakeSyncAdapter server;

  setUp(() async {
    db = await LocalDb.open(name: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    server = FakeSyncAdapter();
    final api = ApiClient(baseUrl: 'https://test.local', tokenProvider: () async => 't');
    api.dio.httpClientAdapter = server;
    repo = LibraryRepository(api, db);
  });

  tearDown(() => db.close());

  final hobbit = Book(workKey: 'OL1W', title: 'Hobbit', authors: ['Tolkien']);

  test('cambios offline se compactan por libro', () async {
    await repo.setFavorite(1, hobbit, true);
    await repo.setFavorite(1, hobbit, false);
    await repo.setFavorite(1, hobbit, true);
    expect(await repo.pendingCount(1), 1);
    expect(await repo.isFavorite(1, 'OL1W'), isTrue);
  });

  test('datos separados por usuario', () async {
    await repo.setFavorite(1, hobbit, true);
    expect(await repo.favorites(2), isEmpty);
    expect(await repo.pendingCount(2), 0);
  });

  test('respuesta perdida + reintento = sin duplicados ni pérdidas', () async {
    await repo.setFavorite(1, hobbit, true);
    await repo.addHistory(1, 'tolkien', 10);
    server.failNext = true;
    await expectLater(repo.sync(1), throwsA(anything));
    expect(await repo.pendingCount(1), 2, reason: 'la cola se conserva si no hubo respuesta');

    final report = await repo.sync(1);
    expect(report.duplicates, 2);
    expect(await repo.pendingCount(1), 0);
    expect(server.favorites.keys, ['OL1W']);
    expect((await repo.favorites(1)).single.workKey, 'OL1W');
    expect(
      server.requests[0].map((o) => o['op_id']).toList(),
      server.requests[1].map((o) => o['op_id']).toList(),
    );
  });
}
