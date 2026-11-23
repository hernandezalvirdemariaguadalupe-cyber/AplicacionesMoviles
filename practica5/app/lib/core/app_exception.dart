import 'package:dio/dio.dart';

enum ErrorKind { network, timeout, http, unauthorized, forbidden, rateLimited, malformed, unknown }

/// Error normalizado para que la UI muestre un mensaje claro y nunca se cierre la app.
class AppException implements Exception {
  AppException(this.kind, this.message, {this.statusCode});

  final ErrorKind kind;
  final String message;
  final int? statusCode;

  bool get isOffline => kind == ErrorKind.network || kind == ErrorKind.timeout;

  String get title => switch (kind) {
    ErrorKind.network => 'Sin conexión',
    ErrorKind.timeout => 'Tiempo de espera agotado',
    ErrorKind.http => 'Error del servidor (HTTP ${statusCode ?? '?'})',
    ErrorKind.unauthorized => 'Sesión no válida',
    ErrorKind.forbidden => 'Acceso denegado (HTTP 403)',
    ErrorKind.rateLimited => 'Límite de consultas alcanzado',
    ErrorKind.malformed => 'Datos con formato inesperado',
    ErrorKind.unknown => 'Error inesperado',
  };

  @override
  String toString() => '$title: $message';

  static AppException from(Object error) {
    if (error is AppException) return error;
    if (error is DioException) return _fromDio(error);
    if (error is FormatException || error is TypeError) {
      return AppException(ErrorKind.malformed, 'La respuesta no tiene el formato esperado.');
    }
    return AppException(ErrorKind.unknown, error.toString());
  }

  static AppException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return AppException(ErrorKind.timeout, 'El servidor tardó demasiado en responder.');
      case DioExceptionType.connectionError:
        return AppException(ErrorKind.network, 'No se pudo conectar. Revisa tu conexión a Internet.');
      case DioExceptionType.badCertificate:
        return AppException(ErrorKind.network, 'Certificado HTTPS no válido.');
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        final msg = _serverMessage(e.response?.data) ?? 'La petición falló.';
        if (code == 401) return AppException(ErrorKind.unauthorized, msg, statusCode: code);
        if (code == 403) return AppException(ErrorKind.forbidden, msg, statusCode: code);
        if (code == 429) {
          return AppException(
            ErrorKind.rateLimited,
            'Se hicieron demasiadas consultas. Espera un momento e intenta de nuevo.',
            statusCode: code,
          );
        }
        return AppException(ErrorKind.http, msg, statusCode: code);
      case DioExceptionType.cancel:
        return AppException(ErrorKind.unknown, 'Petición cancelada.');
      case DioExceptionType.unknown:
        final inner = e.error;
        if (inner is FormatException) return AppException.from(inner);
        return AppException(ErrorKind.network, 'No se pudo conectar. Revisa tu conexión a Internet.');
    }
  }

  static String? _serverMessage(Object? data) {
    if (data is Map && data['error'] is String) return data['error'] as String;
    return null;
  }
}
