import 'dart:io' show Platform;

import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../core/app_exception.dart';
import '../data/models.dart';
import '../data/session_store.dart';

class AuthRepository {
  AuthRepository(this.api, this.session);

  final ApiClient api;
  final SessionStore session;
  bool _googleReady = false;

  Future<AppUser> _consumeTokenResponse(dynamic data) async {
    final m = asMap(data);
    final token = m['access_token'];
    if (token is! String || token.isEmpty) throw const FormatException('Falta access_token');
    final user = AppUser.fromJson(m['user']);
    await session.save(token, user);
    return user;
  }

  Future<void> register(String username, String password) =>
      api.post('/register', {'username': username, 'password': password}, (_) {}, auth: false);

  Future<AppUser> login(String username, String password) async {
    final data = await api.post(
      '/login',
      {'username': username, 'password': password},
      (d) => d,
      auth: false,
    );
    return _consumeTokenResponse(data);
  }

  Future<void> _initGoogle() async {
    if (_googleReady) return;
    if (!AppConfig.googleConfigured) {
      throw AppException(
        ErrorKind.unknown,
        'Inicio con Google no configurado: falta GOOGLE_SERVER_CLIENT_ID en config.',
      );
    }
    await GoogleSignIn.instance.initialize(
      // En iOS el client ID propio de iOS; en Android se usa el registrado con el SHA-1.
      clientId: Platform.isIOS && AppConfig.googleIosClientId.isNotEmpty ? AppConfig.googleIosClientId : null,
      // Client ID "Web": hace que el ID token tenga como audiencia a nuestro backend.
      serverClientId: AppConfig.googleServerClientId,
    );
    _googleReady = true;
  }

  /// Google -> ID token -> el backend lo valida con las llaves de Google y emite nuestro JWT.
  /// El ID token no se guarda en el dispositivo.
  Future<AppUser?> loginWithGoogle() async {
    await _initGoogle();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AppException(ErrorKind.unknown, 'Google: ${e.description ?? e.code.name}');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw AppException(ErrorKind.unknown, 'Google no devolvió un ID token.');
    }
    final data = await api.post('/auth/google', {'id_token': idToken}, (d) => d, auth: false);
    return _consumeTokenResponse(data);
  }

  /// Restaura la sesión: valida el token con /me si hay red; sin red conserva
  /// la sesión ya validada para consultar los datos locales.
  Future<AppUser?> restore() async {
    final token = await session.token();
    final cached = await session.user();
    if (token == null || cached == null) return null;
    try {
      final fresh = await api.get('/me', AppUser.fromJson);
      await session.updateUser(fresh);
      return fresh;
    } on AppException catch (e) {
      if (e.kind == ErrorKind.unauthorized) {
        await session.clear();
        return null;
      }
      return cached; // offline o servidor caído: sesión previamente validada
    }
  }

  Future<void> logout() async {
    try {
      await api.post('/logout', null, (_) {});
    } catch (_) {
      // Sin red: el token se borra igual del dispositivo.
    }
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await session.clear();
  }
}
