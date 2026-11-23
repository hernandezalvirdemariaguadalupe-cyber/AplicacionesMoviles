import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local (SQLite vía sqflite, disponible en Android e iOS).
/// Todo dato personal lleva user_id para que una sesión nunca lea datos de otra cuenta.
class LocalDb {
  LocalDb._(this.db);

  final Database db;

  static const _version = 1;

  static Future<LocalDb> open({String name = 'biblioteca.db', DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final path = name == inMemoryDatabasePath ? name : p.join(await f.getDatabasesPath(), name);
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(version: _version, onCreate: _create),
    );
    return LocalDb._(db);
  }

  static Future<void> _create(Database db, int version) async {
    final b = db.batch();
    b.execute('''CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    // Copia local de las tareas (CRUD de la Práctica 2) para consulta sin red.
    b.execute('''CREATE TABLE tasks (
      user_id INTEGER NOT NULL, id INTEGER NOT NULL, json TEXT NOT NULL,
      PRIMARY KEY (user_id, id))''');
    // Caché de búsquedas en Open Library (datos públicos, compartidos entre cuentas).
    b.execute('''CREATE TABLE search_cache (
      query TEXT PRIMARY KEY, json TEXT NOT NULL, total INTEGER NOT NULL, fetched_at INTEGER NOT NULL)''');
    // Caché de detalle de libros consultados.
    b.execute('''CREATE TABLE books (
      work_key TEXT PRIMARY KEY, json TEXT NOT NULL, fetched_at INTEGER NOT NULL)''');
    b.execute('''CREATE TABLE history (
      user_id INTEGER NOT NULL, client_id TEXT NOT NULL, query TEXT NOT NULL,
      results_count INTEGER NOT NULL, created_at TEXT NOT NULL, synced INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, client_id))''');
    b.execute('''CREATE TABLE favorites (
      user_id INTEGER NOT NULL, work_key TEXT NOT NULL, json TEXT NOT NULL, updated_at TEXT NOT NULL,
      PRIMARY KEY (user_id, work_key))''');
    // Cola de operaciones pendientes (FIFO). op_id único = idempotencia en el servidor.
    b.execute('''CREATE TABLE pending_ops (
      seq INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, op_id TEXT NOT NULL UNIQUE,
      type TEXT NOT NULL, entity_key TEXT, payload TEXT NOT NULL, timestamp TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT)''');
    b.execute('''CREATE TABLE recommendations (
      user_id INTEGER PRIMARY KEY, json TEXT NOT NULL, criteria TEXT NOT NULL,
      generated_at TEXT NOT NULL, cold_start INTEGER NOT NULL)''');
    await b.commit(noResult: true);
  }

  Future<String?> getMeta(String key) async {
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) =>
      db.insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> close() => db.close();
}
