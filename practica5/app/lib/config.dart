/// Configuración inyectada en compilación con
/// `flutter run --dart-define-from-file=config/dev.json` (ver config/example.json).
/// No se guardan secretos en el código: los client IDs de OAuth son identificadores públicos.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static const openLibraryBaseUrl = 'https://openlibrary.org';
  static const openLibraryCoversUrl = 'https://covers.openlibrary.org';

  static bool get googleConfigured => googleServerClientId.isNotEmpty;

  /// Toda la comunicación remota debe ser HTTPS. Sólo se tolera http en el
  /// emulador/localhost para desarrollo, nunca en un build de release.
  static String? validateApiBaseUrl({required bool releaseMode}) {
    if (apiBaseUrl.isEmpty) {
      return 'Falta API_BASE_URL. Ejecuta con --dart-define-from-file=config/dev.json';
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme) return 'API_BASE_URL no es una URL válida';
    if (uri.scheme == 'https') return null;
    const devHosts = {'10.0.2.2', 'localhost', '127.0.0.1'};
    if (!releaseMode && uri.scheme == 'http' && devHosts.contains(uri.host)) return null;
    return 'API_BASE_URL debe usar HTTPS';
  }
}
