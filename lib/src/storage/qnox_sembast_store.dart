import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:qnox_offline_sync/src/storage/qnox_local_store.dart';
import 'package:qnox_offline_sync/src/models/qnox_sync_task.dart';

class QnoxSembastStore implements QnoxLocalStore {
  late final Database _db;
  final _queue = stringMapStoreFactory.store('queue');
  final _cache = stringMapStoreFactory.store('cache');

  @override
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/qnox_offline_sync.db';
    _db = await databaseFactoryIo.openDatabase(dbPath);
  }

  @override
  Future<void> dispose() async => _db.close();

  @override
  Future<void> enqueue(QnoxSyncTask task) async {
    await _queue.record(task.id).put(_db, task.toMap());
  }

  @override
  Future<List<QnoxSyncTask>> dueTasks({int limit = 20}) async {
    final now = DateTime.now().toIso8601String();
    final finder = Finder(
      filter: Filter.lessThanOrEquals('nextAttemptAt', now),
      sortOrders: [SortOrder('createdAt')],
      limit: limit,
    );
    final recs = await _queue.find(_db, finder: finder);
    return recs.map((s) => QnoxSyncTask.fromMap(s.value)).toList();
  }

  @override
  Future<void> updateTask(QnoxSyncTask task) async {
    await _queue.record(task.id).update(_db, task.toMap());
  }

  @override
  Future<void> removeTask(String id) async {
    await _queue.record(id).delete(_db);
  }

  @override
  Future<int> pendingCount() async => (await _queue.find(_db)).length;

  @override
  Future<void> putCache(
    String cacheKey,
    Map<String, dynamic> payload, {
    required Duration ttl,
  }) async {
    final doc = {
      'payload': payload,
      'updatedAt': DateTime.now().toIso8601String(),
      'ttlMs': ttl.inMilliseconds,
    };
    await _cache.record(cacheKey).put(_db, doc);
  }

  @override
  Future<Map<String, dynamic>?> getCache(String cacheKey) async {
    final rec = await _cache.record(cacheKey).get(_db) as Map<String, dynamic>?;
    if (rec == null) return null;
    final updatedAt = DateTime.parse(rec['updatedAt'] as String);
    final ttlMs = rec['ttlMs'] as int;
    if (DateTime.now().difference(updatedAt).inMilliseconds > ttlMs) {
      await _cache.record(cacheKey).delete(_db);
      return null;
    }
    return (rec['payload'] as Map).cast<String, dynamic>();
  }

  @override
  Future<void> purgeExpiredCache() async {
    final recs = await _cache.find(_db);
    final now = DateTime.now();
    for (final r in recs) {
      final m = r.value as Map<String, dynamic>;
      final updatedAt = DateTime.parse(m['updatedAt'] as String);
      final ttlMs = m['ttlMs'] as int;
      if (now.difference(updatedAt).inMilliseconds > ttlMs) {
        await _cache.record(r.key).delete(_db);
      }
    }
  }
}
