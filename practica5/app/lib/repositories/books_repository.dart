import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../data/local_db.dart';
import '../data/models.dart';

/// API pública: Open Library (https://openlibrary.org/developers/api). JSON, gratuita y sin llave.
class BooksRepository {
  BooksRepository(this.local, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.openLibraryBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              // Open Library pide identificar a los clientes con un User-Agent propio.
              headers: {'User-Agent': 'BibliotecaApp-ESCOM/1.0 (practica academica)'},
            ),
          );

  final LocalDb local;
  final Dio _dio;

  static const _fields = 'key,title,author_name,first_publish_year,cover_i,subject,edition_count';

  static String normalizeQuery(String q) => q.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<List<Book>> _searchRaw(Map<String, dynamic> params) async {
    try {
      final r = await _dio.get('/search.json', queryParameters: {'fields': _fields, ...params});
      final docs = asList(asMap(r.data)['docs']);
      final books = <Book>[];
      for (final d in docs) {
        try {
          books.add(Book.fromSearchDoc(d));
        } on FormatException {
          // Un documento malformado no tira toda la búsqueda.
        }
      }
      return books;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Busca en línea y guarda en caché. Si no hay red, devuelve la última copia guardada.
  Future<SearchPage> search(String rawQuery) async {
    final query = normalizeQuery(rawQuery);
    if (query.isEmpty) throw AppException(ErrorKind.unknown, 'Escribe algo para buscar.');
    final sw = Stopwatch()..start();
    try {
      final r = await _dio.get('/search.json', queryParameters: {'q': query, 'limit': 20, 'fields': _fields});
      sw.stop();
      final m = asMap(r.data);
      final books = <Book>[];
      for (final d in asList(m['docs'])) {
        try {
          books.add(Book.fromSearchDoc(d));
        } on FormatException {
          // se ignora el documento
        }
      }
      final total = (m['numFound'] as num?)?.toInt() ?? books.length;
      final now = DateTime.now().toUtc();
      await local.db.insert('search_cache', {
        'query': query,
        'json': jsonEncode(books.map((b) => b.toJson()).toList()),
        'total': total,
        'fetched_at': now.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return SearchPage(
        query: query,
        books: books,
        total: total,
        fetchedAt: now,
        fromCache: false,
        elapsed: sw.elapsed,
      );
    } catch (e) {
      final err = AppException.from(e);
      if (err.isOffline) {
        final cached = await cachedSearch(query);
        if (cached != null) return cached;
      }
      throw err;
    }
  }

  Future<SearchPage?> cachedSearch(String rawQuery) async {
    final query = normalizeQuery(rawQuery);
    final rows = await local.db.query('search_cache', where: 'query = ?', whereArgs: [query]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final books = asList(jsonDecode(r['json'] as String)).map(Book.fromJson).toList();
    return SearchPage(
      query: query,
      books: books,
      total: r['total'] as int,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(r['fetched_at'] as int, isUtc: true),
      fromCache: true,
    );
  }

  Future<List<String>> cachedQueries() async {
    final rows = await local.db.query('search_cache', columns: ['query'], orderBy: 'fetched_at DESC');
    return rows.map((r) => r['query'] as String).toList();
  }

  /// Detalle de una obra (/works/OLxxxW.json): descripción y temas. Se cachea para verlo sin red.
  Future<(Book, bool fromCache)> detail(Book base) async {
    try {
      final r = await _dio.get('/works/${base.workKey}.json');
      final m = asMap(r.data);
      final desc = m['description'];
      final description = desc is String ? desc : (desc is Map ? '${desc['value'] ?? ''}' : null);
      final subjects = m['subjects'] is List
          ? (m['subjects'] as List).map((e) => '$e').take(25).toList()
          : base.subjects;
      final covers = m['covers'];
      final cover =
          base.coverId ??
          (covers is List && covers.isNotEmpty && covers.first is int && covers.first > 0
              ? covers.first as int
              : null);
      final book = base.copyWith(
        description: description,
        subjects: subjects.isEmpty ? base.subjects : subjects,
        coverId: cover,
      );
      await saveBook(book);
      return (book, false);
    } catch (e) {
      final err = AppException.from(e);
      final cached = await cachedBook(base.workKey);
      if (cached != null && (err.isOffline || err.kind == ErrorKind.rateLimited)) return (cached, true);
      if (err.isOffline) return (base, true);
      throw err;
    }
  }

  Future<void> saveBook(Book book) => local.db.insert('books', {
    'work_key': book.workKey,
    'json': jsonEncode(book.toJson()),
    'fetched_at': DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Book?> cachedBook(String workKey) async {
    final rows = await local.db.query('books', where: 'work_key = ?', whereArgs: [workKey]);
    return rows.isEmpty ? null : Book.fromJson(jsonDecode(rows.first['json'] as String));
  }

  Future<List<Book>> bySubject(String subject, {int limit = 15}) =>
      _searchRaw({'subject': subject, 'limit': limit});

  Future<List<Book>> byAuthor(String author, {int limit = 15}) =>
      _searchRaw({'author': author, 'limit': limit});
}
