import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Cliente HTTP compartido (Dio funciona igual en Android e iOS).
class ApiClient {
  ApiClient({required String baseUrl, required this.tokenProvider, this.onUnauthorized})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenProvider();
          if (token != null && options.extra['auth'] != false) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          if (e.response?.statusCode == 401 && e.requestOptions.extra['auth'] != false) {
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  final Dio dio;
  final Future<String?> Function() tokenProvider;
  final void Function()? onUnauthorized;

  Future<T> _wrap<T>(Future<Response<dynamic>> Function() call, T Function(dynamic) parse) async {
    try {
      final r = await call();
      return parse(r.data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<T> get<T>(String path, T Function(dynamic) parse, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get(path, queryParameters: query), parse);

  Future<T> post<T>(String path, Object? body, T Function(dynamic) parse, {bool auth = true}) => _wrap(
    () => dio.post(
      path,
      data: body,
      options: Options(extra: {'auth': auth}),
    ),
    parse,
  );

  Future<T> put<T>(String path, Object? body, T Function(dynamic) parse) =>
      _wrap(() => dio.put(path, data: body), parse);

  Future<T> delete<T>(String path, T Function(dynamic) parse) => _wrap(() => dio.delete(path), parse);
}

/// Helpers de parseo defensivo: lanzan FormatException (-> "datos malformados")
/// en vez de un TypeError no controlado.
Map<String, dynamic> asMap(dynamic v) {
  if (v is Map) return v.cast<String, dynamic>();
  throw const FormatException('Se esperaba un objeto JSON');
}

List<dynamic> asList(dynamic v) {
  if (v is List) return v;
  throw const FormatException('Se esperaba una lista JSON');
}
