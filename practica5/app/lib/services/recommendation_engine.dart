import '../data/models.dart';

/// Regla de recomendación reproducible (sin IA):
///
/// 1. Perfil de intereses: cada tema y autor de un FAVORITO suma 3 puntos; cada tema y autor
///    de los primeros 5 resultados de una BÚSQUEDA del historial suma 1 punto.
///    Se ignoran temas demasiado genéricos (ver [genericSubjects]).
/// 2. Semillas: los 2 temas y el autor con más puntos (empates -> orden alfabético).
/// 3. Candidatos: libros de Open Library para esas semillas, excluyendo favoritos.
/// 4. Puntaje del candidato = suma de puntos del perfil de sus temas y autores.
///    Orden: puntaje desc, número de ediciones desc, título asc. Se muestran hasta 10.
class RecommendationEngine {
  static const favoriteWeight = 3;
  static const historyWeight = 1;
  static const historyResultsPerQuery = 5;
  static const maxResults = 10;

  static const genericSubjects = {
    'fiction',
    'ficción',
    'literature',
    'general',
    'english language',
    'accessible book',
    'protected daisy',
    'in library',
    'large type books',
    'nyt:combined-print-and-e-book-fiction=',
    'long now manual for civilization',
    'open library staff picks',
    'reading level-grade 7',
    'novela',
    'novel',
    'juvenile literature',
    'translations into spanish',
    'spanish language',
  };

  static String norm(String s) => s.trim().toLowerCase();

  static bool isUsefulSubject(String s) {
    final n = norm(s);
    if (n.isEmpty || n.length > 40) return false;
    if (genericSubjects.contains(n)) return false;
    if (n.contains('=') || n.contains(':')) return false; // etiquetas internas de Open Library
    return true;
  }

  static InterestProfile buildProfile({
    required List<Book> favorites,
    required List<List<Book>> historyResults,
  }) {
    final subjects = <String, int>{};
    final authors = <String, int>{};
    final subjectLabel = <String, String>{};
    final authorLabel = <String, String>{};

    void add(Book b, int w) {
      for (final s in b.subjects.where(isUsefulSubject).toSet()) {
        subjects.update(norm(s), (v) => v + w, ifAbsent: () => w);
        subjectLabel.putIfAbsent(norm(s), () => s);
      }
      for (final a in b.authors.toSet()) {
        authors.update(norm(a), (v) => v + w, ifAbsent: () => w);
        authorLabel.putIfAbsent(norm(a), () => a);
      }
    }

    for (final f in favorites) {
      add(f, favoriteWeight);
    }
    for (final results in historyResults) {
      for (final b in results.take(historyResultsPerQuery)) {
        add(b, historyWeight);
      }
    }
    return InterestProfile(subjects, authors, subjectLabel, authorLabel);
  }

  static List<Recommendation> rank({
    required InterestProfile profile,
    required List<Book> candidates,
    required Set<String> excludeKeys,
  }) {
    final seen = <String>{};
    final scored = <Recommendation>[];
    for (final c in candidates) {
      if (excludeKeys.contains(c.workKey) || !seen.add(c.workKey)) continue;
      var score = 0;
      final matchedSubjects = <String>[];
      final matchedAuthors = <String>[];
      for (final s in c.subjects.map(norm).toSet()) {
        final w = profile.subjects[s];
        if (w != null) {
          score += w;
          matchedSubjects.add(profile.subjectLabels[s] ?? s);
        }
      }
      for (final a in c.authors.map(norm).toSet()) {
        final w = profile.authors[a];
        if (w != null) {
          score += w;
          matchedAuthors.add(profile.authorLabels[a] ?? a);
        }
      }
      if (score == 0) continue;
      final parts = <String>[
        if (matchedAuthors.isNotEmpty) 'autor: ${matchedAuthors.take(2).join(', ')}',
        if (matchedSubjects.isNotEmpty) 'temas: ${matchedSubjects.take(3).join(', ')}',
      ];
      scored.add(Recommendation(book: c, score: score, reason: 'Coincide en ${parts.join(' · ')}'));
    }
    scored.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      final e = b.book.editionCount.compareTo(a.book.editionCount);
      if (e != 0) return e;
      return a.book.title.compareTo(b.book.title);
    });
    return scored.take(maxResults).toList();
  }
}

class InterestProfile {
  InterestProfile(this.subjects, this.authors, this.subjectLabels, this.authorLabels);

  final Map<String, int> subjects;
  final Map<String, int> authors;
  final Map<String, String> subjectLabels;
  final Map<String, String> authorLabels;

  bool get isEmpty => subjects.isEmpty && authors.isEmpty;

  List<MapEntry<String, int>> _top(Map<String, int> m, int n) {
    final list = m.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return list.take(n).toList();
  }

  List<String> topSubjects(int n) => _top(subjects, n).map((e) => subjectLabels[e.key] ?? e.key).toList();
  List<String> topAuthors(int n) => _top(authors, n).map((e) => authorLabels[e.key] ?? e.key).toList();

  String describe() {
    final s = _top(subjects, 2).map((e) => '${subjectLabels[e.key]} (${e.value} pts)').join(', ');
    final a = _top(authors, 1).map((e) => '${authorLabels[e.key]} (${e.value} pts)').join(', ');
    return 'Temas principales: ${s.isEmpty ? '—' : s}. Autor principal: ${a.isEmpty ? '—' : a}.';
  }
}
