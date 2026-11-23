import '../core/api_client.dart';

/// El backend guarda fechas UTC sin zona ("2026-11-01T10:00:00"); se interpretan como UTC.
DateTime parseServerTime(dynamic v) {
  final s = '$v';
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s);
  final parsed = DateTime.tryParse(hasZone ? s : '${s}Z');
  if (parsed == null) throw const FormatException('Fecha malformada');
  return parsed.toUtc();
}

int? _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));

List<String> _strings(dynamic v, [int max = 50]) =>
    v is List ? v.whereType<Object>().map((e) => '$e').take(max).toList() : <String>[];

class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.email,
    this.displayName,
    this.authProvider = 'local',
  });

  final int id;
  final String username;
  final String role;
  final String? email;
  final String? displayName;
  final String authProvider;

  bool get isAdmin => role == 'admin';
  String get label => displayName ?? email ?? username;

  factory AppUser.fromJson(dynamic json) {
    final m = asMap(json);
    final id = _int(m['id']);
    if (id == null || m['username'] is! String) {
      throw const FormatException('Usuario malformado');
    }
    return AppUser(
      id: id,
      username: m['username'] as String,
      role: (m['role'] as String?) ?? 'user',
      email: m['email'] as String?,
      displayName: m['display_name'] as String?,
      authProvider: (m['auth_provider'] as String?) ?? 'local',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'role': role,
    'email': email,
    'display_name': displayName,
    'auth_provider': authProvider,
  };
}

class Task {
  Task({required this.id, required this.title, this.description, this.completed = false, this.updatedAt});

  final int id;
  final String title;
  final String? description;
  final bool completed;
  final String? updatedAt;

  factory Task.fromJson(dynamic json) {
    final m = asMap(json);
    final id = _int(m['id']);
    if (id == null || m['title'] is! String) throw const FormatException('Tarea malformada');
    return Task(
      id: id,
      title: m['title'] as String,
      description: m['description'] as String?,
      completed: m['completed'] == true,
      updatedAt: m['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'completed': completed,
    'updated_at': updatedAt,
  };
}

/// Libro (work) de Open Library.
class Book {
  Book({
    required this.workKey,
    required this.title,
    this.authors = const [],
    this.subjects = const [],
    this.coverId,
    this.firstPublishYear,
    this.editionCount = 0,
    this.description,
  });

  final String workKey; // "OL45883W"
  final String title;
  final List<String> authors;
  final List<String> subjects;
  final int? coverId;
  final int? firstPublishYear;
  final int editionCount;
  final String? description;

  String get authorsLabel => authors.isEmpty ? 'Autor desconocido' : authors.join(', ');

  String? coverUrl(String size) =>
      coverId == null ? null : 'https://covers.openlibrary.org/b/id/$coverId-$size.jpg';

  static String normalizeKey(String raw) => raw.split('/').last;

  /// Documento de /search.json
  factory Book.fromSearchDoc(dynamic json) {
    final m = asMap(json);
    final key = m['key'];
    final title = m['title'];
    if (key is! String || title is! String) throw const FormatException('Resultado malformado');
    return Book(
      workKey: normalizeKey(key),
      title: title,
      authors: _strings(m['author_name'], 10),
      subjects: _strings(m['subject'], 25),
      coverId: _int(m['cover_i']),
      firstPublishYear: _int(m['first_publish_year']),
      editionCount: _int(m['edition_count']) ?? 0,
    );
  }

  /// Formato propio usado en SQLite y en el backend (/me/favorites).
  factory Book.fromJson(dynamic json) {
    final m = asMap(json);
    final key = m['work_key'];
    final title = m['title'];
    if (key is! String || title is! String) throw const FormatException('Libro malformado');
    return Book(
      workKey: normalizeKey(key),
      title: title,
      authors: _strings(m['authors'], 10),
      subjects: _strings(m['subjects'], 25),
      coverId: _int(m['cover_id']),
      firstPublishYear: _int(m['first_publish_year']),
      editionCount: _int(m['edition_count']) ?? 0,
      description: m['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'work_key': workKey,
    'title': title,
    'authors': authors,
    'subjects': subjects,
    'cover_id': coverId,
    'first_publish_year': firstPublishYear,
    'edition_count': editionCount,
    if (description != null) 'description': description,
  };

  Book copyWith({String? description, List<String>? subjects, int? coverId}) => Book(
    workKey: workKey,
    title: title,
    authors: authors,
    subjects: subjects ?? this.subjects,
    coverId: coverId ?? this.coverId,
    firstPublishYear: firstPublishYear,
    editionCount: editionCount,
    description: description ?? this.description,
  );
}

class HistoryEntry {
  HistoryEntry({
    required this.clientId,
    required this.query,
    required this.resultsCount,
    required this.createdAt,
    this.synced = false,
  });

  final String clientId;
  final String query;
  final int resultsCount;
  final DateTime createdAt;
  final bool synced;

  factory HistoryEntry.fromServer(dynamic json) {
    final m = asMap(json);
    return HistoryEntry(
      clientId: '${m['client_id']}',
      query: '${m['query']}',
      resultsCount: _int(m['results_count']) ?? 0,
      createdAt: parseServerTime(m['created_at']),
      synced: true,
    );
  }
}

class SearchPage {
  SearchPage({
    required this.query,
    required this.books,
    required this.total,
    required this.fetchedAt,
    required this.fromCache,
    this.elapsed,
  });

  final String query;
  final List<Book> books;
  final int total;
  final DateTime fetchedAt;
  final bool fromCache;
  final Duration? elapsed;
}

class Recommendation {
  Recommendation({required this.book, required this.score, required this.reason});

  final Book book;
  final int score;
  final String reason;

  Map<String, dynamic> toJson() => {'book': book.toJson(), 'score': score, 'reason': reason};

  factory Recommendation.fromJson(dynamic json) {
    final m = asMap(json);
    return Recommendation(
      book: Book.fromJson(m['book']),
      score: _int(m['score']) ?? 0,
      reason: '${m['reason'] ?? ''}',
    );
  }
}

class RecommendationSet {
  RecommendationSet({
    required this.items,
    required this.criteria,
    required this.generatedAt,
    required this.coldStart,
  });

  final List<Recommendation> items;
  final String criteria;
  final DateTime generatedAt;
  final bool coldStart;
}
