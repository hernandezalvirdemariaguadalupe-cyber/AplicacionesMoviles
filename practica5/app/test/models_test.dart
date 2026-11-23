import 'package:biblioteca_app/core/app_exception.dart';
import 'package:biblioteca_app/data/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsea documento de Open Library', () {
    final book = Book.fromSearchDoc({
      'key': '/works/OL27448W',
      'title': 'The Lord of the Rings',
      'author_name': ['J.R.R. Tolkien'],
      'cover_i': 9255566,
      'first_publish_year': 1954,
      'subject': ['Fantasy'],
    });
    expect(book.workKey, 'OL27448W');
    expect(book.coverUrl('M'), 'https://covers.openlibrary.org/b/id/9255566-M.jpg');
    expect(Book.fromJson(book.toJson()).title, book.title);
  });

  test('datos malformados -> FormatException -> ErrorKind.malformed', () {
    expect(() => Book.fromSearchDoc({'title': 3}), throwsFormatException);
    expect(() => AppUser.fromJson('no soy un mapa'), throwsFormatException);
    expect(AppException.from(const FormatException('x')).kind, ErrorKind.malformed);
  });

  test('fechas del servidor sin zona se leen como UTC', () {
    expect(parseServerTime('2026-11-01T10:00:00').isUtc, isTrue);
    expect(parseServerTime('2026-11-01T10:00:00').hour, 10);
    expect(parseServerTime('2026-11-01T10:00:00Z').hour, 10);
  });

  test('errores HTTP se clasifican', () {
    DioException resp(int code) => DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: RequestOptions(), statusCode: code, data: {'error': 'msg'}),
    );
    expect(AppException.from(resp(403)).kind, ErrorKind.forbidden);
    expect(AppException.from(resp(429)).kind, ErrorKind.rateLimited);
    expect(AppException.from(resp(500)).kind, ErrorKind.http);
    expect(AppException.from(resp(500)).message, 'msg');
    expect(
      AppException.from(
        DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError),
      ).isOffline,
      isTrue,
    );
  });
}
