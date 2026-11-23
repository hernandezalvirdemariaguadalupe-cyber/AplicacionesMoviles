import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

/// Sesión en almacenamiento seguro: Keystore (Android) / Keychain (iOS).
/// El JWT nunca se guarda en SQLite ni en SharedPreferences.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'jwt';
  static const _userKey = 'user';

  String? _cachedToken;

  Future<String?> token() async => _cachedToken ??= await _storage.read(key: _tokenKey);

  Future<AppUser?> user() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String token, AppUser user) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> updateUser(AppUser user) => _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
