import 'package:qnox_offline_sync/src/models/qnox_sync_task.dart';

/// Storage abstraction so we can swap engines (Sembast, Drift, Isar, etc.)
abstract class QnoxLocalStore {
  Future<void> init();
  Future<void> dispose();

  // Queue operations
  Future<void> enqueue(QnoxSyncTask task);
  Future<List<QnoxSyncTask>> dueTasks({int limit = 20});
  Future<void> updateTask(QnoxSyncTask task);
  Future<void> removeTask(String id);
  Future<int> pendingCount();

  // Cache operations (for GET responses)
  Future<void> putCache(
    String cacheKey,
    Map<String, dynamic> payload, {
    required Duration ttl,
  });
  Future<Map<String, dynamic>?> getCache(String cacheKey);
  Future<void> purgeExpiredCache();
}
