import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:qnox_offline_sync/src/models/qnox_sync_task.dart';
import 'package:qnox_offline_sync/src/storage/qnox_local_store.dart';

class QnoxRequestQueue {
  final QnoxLocalStore store;
  final _uuid = const Uuid();
  final Duration initialBackoff;
  final Duration maxBackoff;

  QnoxRequestQueue(this.store, {this.initialBackoff = const Duration(seconds: 3), this.maxBackoff = const Duration(minutes: 2)});

  Future<String> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    final id = _uuid.v4();
    final task = QnoxSyncTask(
      id: id,
      method: method.toUpperCase(),
      path: path,
      data: data,
      headers: headers,
      createdAt: DateTime.now(),
      retries: 0,
      nextAttemptAt: DateTime.now(),
    );
    await store.enqueue(task);
    return id;
  }

  Future<List<QnoxSyncTask>> due({int limit = 20}) => store.dueTasks(limit: limit);

  Future<void> success(QnoxSyncTask t) => store.removeTask(t.id);

  Future<void> retryLater(QnoxSyncTask t) async {
    final nextDelay = _backoff(t.retries);
    await store.updateTask(t.copyWith(
      retries: t.retries + 1,
      nextAttemptAt: DateTime.now().add(nextDelay),
    ));
  }

  Duration _backoff(int retries) {
    final factor = pow(2, retries).toInt();
    final next = initialBackoff * factor;
    return next > maxBackoff ? maxBackoff : next;
  }

  Future<int> pending() => store.pendingCount();
}