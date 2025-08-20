import 'dart:async';
import 'package:logging/logging.dart';
import 'package:qnox_offline_sync/src/models/qnox_sync_task.dart';
import 'package:qnox_offline_sync/src/storage/qnox_local_store.dart';

/// Wraps the local storage to provide higher-level queue semantics
/// (enqueue, mark success, retry later with exponential backoff).
class QnoxRequestQueue {
  final QnoxLocalStore store;
  final _log = Logger('QnoxRequestQueue');

  QnoxRequestQueue(this.store);

  /// Adds a new task into the queue.
  Future<void> enqueue(QnoxSyncTask task) async {
    _log.fine('Enqueue task ${task.id} ${task.method} ${task.path}');
    await store.enqueue(task);
  }

  /// Returns tasks that are due to be retried/executed.
  Future<List<QnoxSyncTask>> due({int limit = 20}) {
    return store.dueTasks(limit: limit);
  }

  /// Mark a task as successfully synced and remove from queue.
  Future<void> success(QnoxSyncTask task) async {
    _log.fine('Task success ${task.id}');
    await store.removeTask(task.id);
  }

  /// Mark a task to retry later, with exponential backoff.
  Future<void> retryLater(QnoxSyncTask task) async {
    final nextAttempt = DateTime.now().add(_backoffDuration(task.attempts));
    final updated = task.copyWith(
      attempts: task.attempts + 1,
      nextAttemptAt: nextAttempt,
    );
    _log.fine('Retry later ${task.id}, attempts=${updated.attempts}');
    await store.updateTask(updated);
  }

  /// How many tasks are still pending.
  Future<int> pending() => store.pendingCount();

  Duration _backoffDuration(int attempts) {
    // Exponential backoff: 2^attempts seconds, capped at 5 minutes
    final secs = (1 << attempts).clamp(1, 300);
    return Duration(seconds: secs);
  }
}