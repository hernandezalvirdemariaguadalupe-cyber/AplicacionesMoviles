import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/api_client.dart';
import '../data/local_db.dart';
import '../data/models.dart';
import '../repositories/books_repository.dart';
import '../repositories/library_repository.dart';
import 'recommendation_engine.dart';

class RecommendationService {
  RecommendationService(this.local, this.books, this.library);

  final LocalDb local;
  final BooksRepository books;
  final LibraryRepository library;

  /// Tema usado cuando el usuario aún no tiene historial ni favoritos (arranque en frío).
  static const coldStartSubject = 'classic literature';

  Future<RecommendationSet?> saved(int userId) async {
    final rows = await local.db.query('recommendations', where: 'user_id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return RecommendationSet(
      items: asList(jsonDecode(r['json'] as String)).map(Recommendation.fromJson).toList(),
      criteria: r['criteria'] as String,
      generatedAt: DateTime.parse(r['generated_at'] as String),
      coldStart: r['cold_start'] == 1,
    );
  }

  Future<RecommendationSet> generate(int userId) async {
    final favorites = await library.favorites(userId);
    final history = await library.history(userId);
    final historyResults = <List<Book>>[];
    for (final q in history.map((h) => h.query).toSet().take(20)) {
      final page = await books.cachedSearch(q);
      if (page != null) historyResults.add(page.books);
    }
    final profile = RecommendationEngine.buildProfile(favorites: favorites, historyResults: historyResults);

    final RecommendationSet set;
    if (profile.isEmpty) {
      final list = await books.bySubject(coldStartSubject, limit: 10);
      set = RecommendationSet(
        items: list
            .map((b) => Recommendation(book: b, score: 0, reason: 'Sugerencia inicial: clásico popular'))
            .toList(),
        criteria:
            'Aún no tienes favoritos ni búsquedas, así que se muestran clásicos populares '
            '(tema «$coldStartSubject»). Busca libros y marca favoritos para personalizar.',
        generatedAt: DateTime.now().toUtc(),
        coldStart: true,
      );
    } else {
      final candidates = <Book>[];
      for (final s in profile.topSubjects(2)) {
        candidates.addAll(await books.bySubject(s.toLowerCase()));
      }
      for (final a in profile.topAuthors(1)) {
        candidates.addAll(await books.byAuthor(a));
      }
      // También se consideran resultados ya guardados del historial (funciona aunque la API limite).
      for (final r in historyResults) {
        candidates.addAll(r);
      }
      final ranked = RecommendationEngine.rank(
        profile: profile,
        candidates: candidates,
        excludeKeys: favorites.map((f) => f.workKey).toSet(),
      );
      set = RecommendationSet(
        items: ranked,
        criteria:
            'Favoritos ×${RecommendationEngine.favoriteWeight}, búsquedas ×${RecommendationEngine.historyWeight}. '
            '${profile.describe()} Se excluyen tus favoritos.',
        generatedAt: DateTime.now().toUtc(),
        coldStart: false,
      );
    }

    await local.db.insert('recommendations', {
      'user_id': userId,
      'json': jsonEncode(set.items.map((r) => r.toJson()).toList()),
      'criteria': set.criteria,
      'generated_at': set.generatedAt.toIso8601String(),
      'cold_start': set.coldStart ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return set;
  }
}
