// lib/src/storage/qnox_sembast_store.dart

import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import 'package:qnox_offline_sync/src/models/qnox_sync_task.dart';
import 'package:qnox_offline_sync/src/storage/qnox_local_store.dart';

/// Default Sembast-backed storage for queue + cache.
/// Mobile/desktop friendly. (For web, use a different impl like sembast_web.)
class QnoxSembastStore implements QnoxLocalStore {
  static const _dbFileName = 'qnox_offline_sync.db';

  late final Database _db;
  final StoreRef<String, Map<String, Object?>> _queue = stringMapStoreFactory
      .store('queue');
  final StoreRef<String, Map<String, Object?>> _cache = stringMapStoreFactory
      .store('cache');

  @override
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/$_dbFileName';
    _db = await databaseFactoryIo.openDatabase(dbPath);
  }

  @override
  Future<void> dispose() async {
    await _db.close();
  }

  // -------------------------
  // Queue
  // -------------------------

  @override
  Future<void> enqueue(QnoxSyncTask task) async {
    await _queue.record(task.id).put(_db, _encodeTask(task));
  }

  @override
  Future<List<QnoxSyncTask>> dueTasks({int limit = 20}) async {
    final nowIso = DateTime.now().toIso8601String();
    final finder = Finder(
      filter: Filter.lessThanOrEquals('nextAttemptAt', nowIso),
      sortOrders: [SortOrder('createdAt')], // oldest first
      limit: limit,
    );
    final records = await _queue.find(_db, finder: finder);
    return records.map((r) => _decodeTask(r.value)).toList();
  }

  @override
  Future<void> updateTask(QnoxSyncTask task) async {
    await _queue.record(task.id).update(_db, _encodeTask(task));
  }

  @override
  Future<void> removeTask(String id) async {
    await _queue.record(id).delete(_db);
  }

  @override
  Future<int> pendingCount() async {
    final records = await _queue.find(_db);
    return records.length;
  }

  // -------------------------
  // Cache
  // -------------------------

  @override
  Future<void> putCache(
    String cacheKey,
    Map<String, dynamic> payload, {
    required Duration ttl,
  }) async {
    final doc = <String, Object?>{
      'payload': payload,
      'updatedAt': DateTime.now().toIso8601String(),
      'ttlMs': ttl.inMilliseconds,
    };
    await _cache.record(cacheKey).put(_db, doc);
  }

  @override
  Future<Map<String, dynamic>?> getCache(String cacheKey) async {
    final doc = await _cache.record(cacheKey).get(_db);
    if (doc == null) return null;

    final updatedAt = DateTime.tryParse((doc['updatedAt'] as String?) ?? '');
    final ttlMs = (doc['ttlMs'] as int?) ?? 0;
    if (updatedAt == null) {
      // Corrupt entry — remove
      await _cache.record(cacheKey).delete(_db);
      return null;
    }

    final expired = DateTime.now().difference(updatedAt).inMilliseconds > ttlMs;
    if (expired) {
      await _cache.record(cacheKey).delete(_db);
      return null;
    }

    final payload = doc['payload'];
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  @override
  Future<void> purgeExpiredCache() async {
    final now = DateTime.now();
    final rows = await _cache.find(_db);
    for (final r in rows) {
      final m = r.value;
      final updatedAt = DateTime.tryParse((m['updatedAt'] as String?) ?? '');
      final ttlMs = (m['ttlMs'] as int?) ?? 0;
      if (updatedAt == null) {
        await _cache.record(r.key).delete(_db);
        continue;
      }
      final expired = now.difference(updatedAt).inMilliseconds > ttlMs;
      if (expired) {
        await _cache.record(r.key).delete(_db);
      }
    }
  }

  // -------------------------
  // Helpers
  // -------------------------

  Map<String, Object?> _encodeTask(QnoxSyncTask t) => <String, Object?>{
    'id': t.id,
    'method': t.method,
    'path': t.path,
    'data': t.data,
    'headers': t.headers,
    'attempts': t.attempts,
    'nextAttemptAt': t.nextAttemptAt.toIso8601String(),
    'createdAt': t.createdAt.toIso8601String(),
  };

  QnoxSyncTask _decodeTask(Map<String, Object?> m) => QnoxSyncTask(
    id: (m['id'] as String?) ?? '',
    method: (m['method'] as String?) ?? 'POST',
    path: (m['path'] as String?) ?? '',
    data: (m['data'] is Map)
        ? Map<String, dynamic>.from(m['data'] as Map)
        : null,
    headers: (m['headers'] is Map)
        ? Map<String, String>.from(m['headers'] as Map)
        : null,
    attempts: (m['attempts'] as int?) ?? 0,
    nextAttemptAt:
        DateTime.tryParse((m['nextAttemptAt'] as String?) ?? '') ??
        DateTime.now(),
    createdAt:
        DateTime.tryParse((m['createdAt'] as String?) ?? '') ?? DateTime.now(),
  );
}
