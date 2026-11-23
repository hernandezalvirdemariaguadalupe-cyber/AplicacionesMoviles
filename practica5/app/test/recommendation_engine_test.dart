import 'package:biblioteca_app/data/models.dart';
import 'package:biblioteca_app/services/recommendation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Book b(String key, String title, {List<String> a = const [], List<String> s = const [], int ed = 1}) =>
    Book(workKey: key, title: title, authors: a, subjects: s, editionCount: ed);

void main() {
  test('favoritos pesan 3 y búsquedas 1; temas genéricos se ignoran', () {
    final p = RecommendationEngine.buildProfile(
      favorites: [
        b('OL1W', 'Hobbit', a: ['J.R.R. Tolkien'], s: ['Fantasy', 'Fiction', 'Dragons']),
      ],
      historyResults: [
        [
          b('OL2W', 'Dune', a: ['Frank Herbert'], s: ['Science fiction', 'Fantasy']),
        ],
      ],
    );
    expect(p.subjects['fantasy'], 4);
    expect(p.subjects['dragons'], 3);
    expect(p.subjects.containsKey('fiction'), isFalse);
    expect(p.authors['j.r.r. tolkien'], 3);
    expect(p.topSubjects(2), ['Fantasy', 'Dragons']);
    expect(p.topAuthors(1), ['J.R.R. Tolkien']);
  });

  test('ranking reproducible, excluye favoritos y sin coincidencias', () {
    final p = RecommendationEngine.buildProfile(
      favorites: [
        b('OL1W', 'Hobbit', a: ['J.R.R. Tolkien'], s: ['Fantasy']),
      ],
      historyResults: const [],
    );
    final recs = RecommendationEngine.rank(
      profile: p,
      candidates: [
        b('OL1W', 'Hobbit', a: ['J.R.R. Tolkien'], s: ['Fantasy']), // favorito
        b('OL3W', 'Silmarillion', a: ['J.R.R. Tolkien'], s: ['Fantasy']), // 6
        b('OL4W', 'Earthsea', a: ['Le Guin'], s: ['Fantasy'], ed: 50), // 3
        b('OL5W', 'Narnia', a: ['Lewis'], s: ['fantasy'], ed: 10), // 3
        b('OL6W', 'Cocina', a: ['X'], s: ['Cooking']), // 0
        b('OL3W', 'Silmarillion', a: ['J.R.R. Tolkien'], s: ['Fantasy']), // duplicado
      ],
      excludeKeys: {'OL1W'},
    );
    expect(recs.map((r) => r.book.workKey), ['OL3W', 'OL4W', 'OL5W']);
    expect(recs.first.score, 6);
    expect(recs.first.reason, contains('J.R.R. Tolkien'));
  });

  test('perfil vacío -> arranque en frío', () {
    final p = RecommendationEngine.buildProfile(favorites: const [], historyResults: const []);
    expect(p.isEmpty, isTrue);
  });
}
