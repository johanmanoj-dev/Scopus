import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../utils/app_time.dart';

/// Singleton database for tracking locally cached Drive files.
///
/// Knows which files have been downloaded to avoid re-fetching them
/// from Google Drive on every open.
class CacheDatabase {
  static final CacheDatabase _instance = CacheDatabase._internal();
  factory CacheDatabase() => _instance;
  CacheDatabase._internal();

  Database? _db;
  final StreamController<void> _queueUpdates = StreamController<void>.broadcast();
  Stream<void> get onQueueChanged => _queueUpdates.stream;

  /// Initializes the SQLite database and creates the file_cache table.
  /// Must be called in `main()` before the app runs.
  Future<void> init() async {
    if (_db != null) return;

    final appSupportDir = await getApplicationSupportDirectory();
    final dbPath = join(appSupportDir.path, 'cache', 'cache.db');

    // Ensure the cache directory exists
    await Directory(dirname(dbPath)).create(recursive: true);

    Future<void> onCreate(Database db, int version) async {
      await db.execute('''
        CREATE TABLE file_cache (
          drive_file_id  TEXT PRIMARY KEY,
          local_path     TEXT NOT NULL,
          subject_id     TEXT NOT NULL,
          file_name      TEXT NOT NULL,
          cached_at      INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE offline_queue (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          operation  TEXT NOT NULL,
          payload    TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
    }

    Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE offline_queue (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            operation  TEXT NOT NULL,
            payload    TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      }
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // Native sqflite — no FFI needed on mobile
      _db = await sqflite.openDatabase(
        dbPath,
        version: 2,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
    } else {
      // Desktop: use FFI factory (initialized in main())
      _db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: onCreate,
          onUpgrade: onUpgrade,
        ),
      );
    }
  }

  Database get db {
    if (_db == null) {
      throw StateError('CacheDatabase has not been initialized. Call init() first.');
    }
    return _db!;
  }

  /// Records a downloaded file in the local cache database.
  Future<void> insertCache(
    String driveFileId,
    String localPath,
    String subjectId,
    String fileName,
  ) async {
    await db.insert(
      'file_cache',
      {
        'drive_file_id': driveFileId,
        'local_path': localPath,
        'subject_id': subjectId,
        'file_name': fileName,
        'cached_at': AppTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the local path for [driveFileId] if it exists in the cache,
  /// otherwise returns null.
  Future<String?> getLocalPath(String driveFileId) async {
    final result = await db.query(
      'file_cache',
      columns: ['local_path'],
      where: 'drive_file_id = ?',
      whereArgs: [driveFileId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['local_path'] as String?;
  }

  /// Removes a single file from the cache tracking.
  /// Called when a user deletes a file from Drive.
  Future<void> deleteCache(String driveFileId) async {
    await db.delete(
      'file_cache',
      where: 'drive_file_id = ?',
      whereArgs: [driveFileId],
    );
  }

  /// Clears all cached file records for a given [subjectId].
  /// Does NOT delete the physical files; the caller should handle physical file deletion if needed,
  /// but typically the whole directory is wiped when a subject is deleted.
  Future<void> clearSubjectCache(String subjectId) async {
    await db.delete(
      'file_cache',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
    );
  }

  // ── Phase 6: Offline Queue ─────────────────────────────────────

  /// Inserts a pending operation into the offline queue.
  Future<void> enqueueOperation(String operation, String payload) async {
    await db.insert('offline_queue', {
      'operation': operation,
      'payload': payload,
      'created_at': AppTime.now().millisecondsSinceEpoch,
    });
    _queueUpdates.add(null);
  }

  /// Retrieves all pending operations, ordered by oldest first.
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    return await db.query(
      'offline_queue',
      orderBy: 'created_at ASC',
    );
  }

  /// Removes an operation from the queue after it has been successfully synced.
  Future<void> deleteOperation(int id) async {
    await db.delete(
      'offline_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    _queueUpdates.add(null);
  }
}
