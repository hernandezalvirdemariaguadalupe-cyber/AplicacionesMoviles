import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'core/api_client.dart';
import 'core/app_exception.dart';
import 'data/local_db.dart';
import 'data/models.dart';
import 'data/session_store.dart';
import 'repositories/auth_repository.dart';
import 'repositories/books_repository.dart';
import 'repositories/library_repository.dart';
import 'repositories/task_repository.dart';
import 'services/recommendation_service.dart';

enum SyncStatus { idle, syncing, ok, error, waitingNetwork }

/// Estado global: sesión, conectividad y sincronización con reintentos.
class AppState extends ChangeNotifier {
  AppState({
    required this.local,
    required String apiBaseUrl,
    SessionStore? session,
    Connectivity? connectivity,
  }) : session = session ?? SessionStore(),
       _connectivity = connectivity ?? Connectivity() {
    api = ApiClient(
      baseUrl: apiBaseUrl,
      tokenProvider: this.session.token,
      onUnauthorized: _handleUnauthorized,
    );
    auth = AuthRepository(api, this.session);
    tasks = TaskRepository(api, local);
    books = BooksRepository(local);
    library = LibraryRepository(api, local);
    recommendations = RecommendationService(local, books, library);
  }

  final LocalDb local;
  final SessionStore session;
  final Connectivity _connectivity;
  late final ApiClient api;
  late final AuthRepository auth;
  late final TaskRepository tasks;
  late final BooksRepository books;
  late final LibraryRepository library;
  late final RecommendationService recommendations;

  AppUser? user;
  bool initializing = true;
  bool online = true;
  SyncStatus syncStatus = SyncStatus.idle;
  String? syncMessage;
  DateTime? lastSync;
  int pendingOps = 0;

  /// Se incrementa cada vez que cambian datos locales (favoritos, historial) para refrescar pantallas.
  int dataVersion = 0;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _syncRunning = false;
  bool _syncAgain = false;
  static const maxRetries = 5;

  int get uid => user!.id;

  Future<void> init() async {
    final initial = await _connectivity.checkConnectivity();
    online = _isOnline(initial);
    _connSub = _connectivity.onConnectivityChanged.listen(_onConnectivity);
    user = await auth.restore();
    initializing = false;
    notifyListeners();
    if (user != null) await _afterLogin();
  }

  bool _isOnline(List<ConnectivityResult> r) => r.any((c) => c != ConnectivityResult.none);

  void _onConnectivity(List<ConnectivityResult> r) {
    final wasOnline = online;
    online = _isOnline(r);
    notifyListeners();
    if (!wasOnline && online && user != null) {
      // Recuperación de conexión: sincronización explícita.
      _retryAttempt = 0;
      sync(reason: 'reconexión');
    }
  }

  Future<void> _afterLogin() async {
    lastSync = await library.lastSync(uid);
    pendingOps = await library.pendingCount(uid);
    notifyListeners();
    await sync(reason: 'inicio');
  }

  // ---------------- sesión ----------------

  Future<void> login(String username, String password) async {
    user = await auth.login(username, password);
    notifyListeners();
    await _afterLogin();
  }

  Future<void> register(String username, String password) async {
    await auth.register(username, password);
    await login(username, password);
  }

  Future<bool> loginWithGoogle() async {
    final u = await auth.loginWithGoogle();
    if (u == null) return false; // cancelado por el usuario
    user = u;
    notifyListeners();
    await _afterLogin();
    return true;
  }

  Future<void> logout() async {
    _retryTimer?.cancel();
    await auth.logout();
    user = null;
    syncStatus = SyncStatus.idle;
    syncMessage = null;
    notifyListeners();
  }

  void _handleUnauthorized() {
    if (user == null) return;
    session.clear();
    user = null;
    syncMessage = 'Tu sesión expiró. Inicia sesión de nuevo.';
    notifyListeners();
  }

  // ---------------- datos locales ----------------

  Future<void> localDataChanged({bool trySync = true}) async {
    if (user == null) return;
    dataVersion++;
    pendingOps = await library.pendingCount(uid);
    notifyListeners();
    if (trySync) unawaited(sync(reason: 'cambio local'));
  }

  // ---------------- sincronización ----------------

  /// Sincroniza la cola pendiente. Reintentos con espera exponencial (2, 4, 8, 16, 32 s);
  /// si se agotan, se vuelve a intentar al recuperar la red o con el botón "Sincronizar".
  Future<void> sync({String reason = 'manual'}) async {
    if (user == null) return;
    if (_syncRunning) {
      _syncAgain = true;
      return;
    }
    if (!online) {
      syncStatus = SyncStatus.waitingNetwork;
      syncMessage =
          'Sin conexión: ${pendingOps > 0 ? '$pendingOps cambios en cola' : 'mostrando datos guardados'}';
      notifyListeners();
      return;
    }
    _syncRunning = true;
    _retryTimer?.cancel();
    syncStatus = SyncStatus.syncing;
    syncMessage = 'Sincronizando ($reason)…';
    notifyListeners();
    final userId = uid;
    try {
      final report = await library.sync(userId);
      if (user?.id != userId) return; // cerró sesión durante la sincronización
      _retryAttempt = 0;
      lastSync = await library.lastSync(userId);
      pendingOps = await library.pendingCount(userId);
      syncStatus = SyncStatus.ok;
      syncMessage = report.sent == 0 ? 'Datos actualizados' : 'Sincronizado: $report';
      dataVersion++;
    } catch (e) {
      final err = AppException.from(e);
      if (err.kind == ErrorKind.unauthorized) return;
      syncStatus = SyncStatus.error;
      if (_retryAttempt < maxRetries) {
        final delay = Duration(seconds: 2 << _retryAttempt);
        _retryAttempt++;
        syncMessage = '${err.title}. Reintento $_retryAttempt/$maxRetries en ${delay.inSeconds} s';
        _retryTimer = Timer(delay, () => sync(reason: 'reintento $_retryAttempt'));
      } else {
        syncMessage = '${err.title}. Se reintentará al reconectar o con "Sincronizar".';
        _retryAttempt = 0;
      }
    } finally {
      _syncRunning = false;
      notifyListeners();
    }
    if (_syncAgain) {
      _syncAgain = false;
      await sync(reason: 'cambios nuevos');
    }
  }

  /// Para pruebas/demostración: simula la pérdida de red sin apagar el dispositivo.
  @visibleForTesting
  void debugSetOnline(bool value) =>
      _onConnectivity(value ? [ConnectivityResult.wifi] : [ConnectivityResult.none]);

  @override
  void dispose() {
    _connSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
