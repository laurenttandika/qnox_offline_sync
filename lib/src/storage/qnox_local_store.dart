import 'package:qnox_offline_sync/src/models/qnox_sync_task.dart';

/// Storage abstraction for the offline queue and cache.
///
/// Implement this to plug in your own backend (Sembast/Drift/Isar/Hive/SQLite).
/// The semantics are intentionally simple and deterministic:
/// - Queue is append-only with update/remove operations
/// - Tasks become eligible when `nextAttemptAt <= now`
/// - Cache entries expire based on a TTL you store alongside payloads
abstract class QnoxLocalStore {
  /// Open connections, create tables/boxes if needed.
  Future<void> init();

  /// Close any open handles.
  Future<void> dispose();

  // -------------------------
  // Queue operations
  // -------------------------

  /// Persist a new task.
  Future<void> enqueue(QnoxSyncTask task);

  /// Return tasks whose `nextAttemptAt <= now`, ordered by `createdAt` ASC.
  Future<List<QnoxSyncTask>> dueTasks({int limit = 20});

  /// Overwrite an existing task (matched by `task.id`).
  Future<void> updateTask(QnoxSyncTask task);

  /// Remove a task permanently.
  Future<void> removeTask(String id);

  /// Count all pending tasks (useful for status UI).
  Future<int> pendingCount();

  // -------------------------
  // Cache operations (for GETs)
  // -------------------------

  /// Insert or upsert a cached payload with a TTL.
  ///
  /// Implementations should store:
  /// - `payload` (JSON map)
  /// - `updatedAt = now`
  /// - `ttlMs = ttl.inMilliseconds`
  Future<void> putCache(
    String cacheKey,
    Map<String, dynamic> payload, {
    required Duration ttl,
  });

  /// Retrieve a cached payload if not expired; otherwise return `null`.
  ///
  /// Implementations should check:
  /// `now - updatedAt <= ttlMs`
  /// and delete/ignore expired entries.
  Future<Map<String, dynamic>?> getCache(String cacheKey);

  /// Remove all expired cache entries.
  Future<void> purgeExpiredCache();
}