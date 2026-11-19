import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../core/errors.dart';
import 'models.dart';
import 'native_storage.dart';
import 'sample_files.dart';
import 'storage_service.dart';
import 'thumbnail_cache.dart';

/// Operación pendiente de "Pegar".
class ClipboardOp {
  final FsEntry entry;
  final bool move;
  ClipboardOp(this.entry, {required this.move});
}

/// Estado global de la app.
///
/// Persistencia: se usa SharedPreferences (NSUserDefaults en iOS, SharedPreferences XML
/// en Android), compatible con ambos sistemas, guardando listas en JSON para:
/// tema, modo claro/oscuro, ubicaciones autorizadas, recientes y favoritos.
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  static const _kPalette = 'palette';
  static const _kMode = 'themeMode';
  static const _kLocations = 'locations';
  static const _kRecents = 'recents';
  static const _kFavorites = 'favorites';
  static const _kGrid = 'gridView';
  static const maxRecents = 30;

  final SharedPreferences _prefs;
  final storage = StorageService();
  late final thumbnails = ThumbnailCache(storage);

  AppPalette palette = AppPalette.guinda;
  ThemeMode themeMode = ThemeMode.system;
  bool gridView = false;
  late StorageLocation appLocation;
  List<StorageLocation> locations = [];
  List<SavedRef> recents = [];
  List<SavedRef> favorites = [];
  ClipboardOp? clipboard;

  static Future<AppState> load() async {
    final s = AppState(await SharedPreferences.getInstance());
    await s._init();
    return s;
  }

  Future<void> _init() async {
    palette = AppPalette.values.asNameMap()[_prefs.getString(_kPalette)] ?? AppPalette.guinda;
    themeMode = ThemeMode.values.asNameMap()[_prefs.getString(_kMode)] ?? ThemeMode.system;
    gridView = _prefs.getBool(_kGrid) ?? false;

    final dir = await StorageService.appStorageDir();
    appLocation = StorageLocation(
      id: 'app',
      kind: LocationKind.appStorage,
      name: Platform.isIOS ? 'En mi iPhone (app)' : 'Almacenamiento de la app',
      ref: dir.path,
    );
    await SampleFiles.ensure(dir);

    locations = _readList(_kLocations, StorageLocation.fromJson);
    recents = _readList(_kRecents, SavedRef.fromJson);
    favorites = _readList(_kFavorites, SavedRef.fromJson);
    await verifyLocations();
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) parse) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => parse(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return []; // datos dañados: se reinicia sólo esa lista
    }
  }

  Future<void> _save(String key, List<dynamic> list) =>
      _prefs.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));

  // ------------------------------------------------------------------ tema

  void setPalette(AppPalette p) {
    palette = p;
    _prefs.setString(_kPalette, p.name);
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _prefs.setString(_kMode, m.name);
    notifyListeners();
  }

  void toggleGrid() {
    gridView = !gridView;
    _prefs.setBool(_kGrid, gridView);
    notifyListeners();
  }

  // ------------------------------------------------------------------ ubicaciones

  /// Comprueba que cada ubicación siga accesible (permiso no revocado / bookmark válido).
  Future<void> verifyLocations() async {
    if (Platform.isAndroid) {
      List<String> persisted = const [];
      try {
        persisted = await NativeStorage.persistedRoots();
      } catch (_) {}
      for (final l in locations) {
        final grant = l.treeUri ?? l.ref;
        l.available = persisted.contains(grant);
      }
    } else if (Platform.isIOS) {
      for (var i = 0; i < locations.length; i++) {
        final l = locations[i];
        if (l.bookmark == null) {
          l.available = false;
          continue;
        }
        try {
          final r = await NativeStorage.resolveBookmark(l.bookmark!);
          locations[i] = l.copyWith(ref: r!['ref'] as String, bookmark: r['bookmark'] as String?, available: true);
        } catch (_) {
          l.available = false;
        }
      }
      await _save(_kLocations, locations);
    }
    notifyListeners();
  }

  /// Pide al sistema una carpeta. Devuelve null si el usuario canceló.
  Future<StorageLocation?> addFolder() async {
    final r = await NativeStorage.pickDirectory();
    if (r == null) return null;
    final entry = FsEntry.fromMap(r);
    final loc = StorageLocation(
      id: 'loc_${DateTime.now().microsecondsSinceEpoch}',
      kind: LocationKind.folder,
      name: entry.name,
      ref: entry.ref,
      bookmark: r['bookmark'] as String?,
      treeUri: r['treeUri'] as String?,
    );
    locations.removeWhere((l) => l.ref == loc.ref);
    locations.add(loc);
    await _save(_kLocations, locations);
    notifyListeners();
    return loc;
  }

  /// Pide al sistema uno o varios archivos sueltos.
  Future<List<StorageLocation>> addFiles() async {
    final picked = await NativeStorage.pickFiles();
    final added = <StorageLocation>[];
    for (final r in picked) {
      final entry = FsEntry.fromMap(r);
      final loc = StorageLocation(
        id: 'file_${DateTime.now().microsecondsSinceEpoch}_${added.length}',
        kind: LocationKind.file,
        name: entry.name,
        ref: entry.ref,
        bookmark: r['bookmark'] as String?,
      );
      locations.removeWhere((l) => l.ref == loc.ref);
      locations.add(loc);
      added.add(loc);
    }
    await _save(_kLocations, locations);
    notifyListeners();
    return added;
  }

  Future<void> removeLocation(StorageLocation l) async {
    locations.removeWhere((x) => x.id == l.id);
    try {
      await NativeStorage.release(l.treeUri ?? l.ref);
    } catch (_) {}
    recents.removeWhere((r) => r.locationId == l.id);
    favorites.removeWhere((r) => r.locationId == l.id);
    await _save(_kLocations, locations);
    await _save(_kRecents, recents);
    await _save(_kFavorites, favorites);
    notifyListeners();
  }

  StorageLocation? locationById(String id) =>
      id == 'app' ? appLocation : locations.where((l) => l.id == id).firstOrNull;

  // ------------------------------------------------------------------ recientes / favoritos

  Future<void> addRecent(FsEntry e, String locationId) async {
    recents.removeWhere((r) => r.ref == e.ref);
    recents.insert(0, SavedRef(ref: e.ref, name: e.name, isDir: e.isDir, locationId: locationId));
    if (recents.length > maxRecents) recents = recents.sublist(0, maxRecents);
    await _save(_kRecents, recents);
    notifyListeners();
  }

  Future<void> clearRecents() async {
    recents.clear();
    await _save(_kRecents, recents);
    notifyListeners();
  }

  Future<void> removeRecent(String ref) async {
    recents.removeWhere((r) => r.ref == ref);
    await _save(_kRecents, recents);
    notifyListeners();
  }

  bool isFavorite(String ref) => favorites.any((f) => f.ref == ref);

  Future<void> toggleFavorite(FsEntry e, String locationId) async {
    if (isFavorite(e.ref)) {
      favorites.removeWhere((f) => f.ref == e.ref);
    } else {
      favorites.insert(0, SavedRef(ref: e.ref, name: e.name, isDir: e.isDir, locationId: locationId));
    }
    await _save(_kFavorites, favorites);
    notifyListeners();
  }

  Future<void> removeFavorite(String ref) async {
    favorites.removeWhere((f) => f.ref == ref);
    await _save(_kFavorites, favorites);
    notifyListeners();
  }

  /// Actualiza recientes y favoritos cuando un elemento cambia de referencia
  /// (renombrar o mover) o desaparece (eliminar → [newRef] null).
  Future<void> refChanged(String oldRef, String? newRef, {String? newName}) async {
    List<SavedRef> fix(List<SavedRef> list) {
      final out = <SavedRef>[];
      for (final r in list) {
        final affected = r.ref == oldRef || r.ref.startsWith('$oldRef/');
        if (!affected) {
          out.add(r);
        } else if (newRef != null) {
          out.add(SavedRef(
            ref: r.ref == oldRef ? newRef : newRef + r.ref.substring(oldRef.length),
            name: r.ref == oldRef ? (newName ?? r.name) : r.name,
            isDir: r.isDir,
            locationId: r.locationId,
            at: r.at,
          ));
        }
        // eliminado → se descarta
      }
      return out;
    }
    recents = fix(recents);
    favorites = fix(favorites);
    await _save(_kRecents, recents);
    await _save(_kFavorites, favorites);
    notifyListeners();
  }

  // ------------------------------------------------------------------ portapapeles

  void setClipboard(FsEntry e, {required bool move}) {
    clipboard = ClipboardOp(e, move: move);
    notifyListeners();
  }

  void clearClipboard() {
    clipboard = null;
    notifyListeners();
  }

  Future<String> paste(FsEntry destDir) async {
    final op = clipboard;
    if (op == null) throw const FsException(FsErrorKind.unknown, 'No hay nada que pegar.');
    final created = await storage.copy(op.entry, destDir, move: op.move);
    if (op.move) {
      await refChanged(op.entry.ref, created);
      clipboard = null;
    }
    notifyListeners();
    return created;
  }
}
