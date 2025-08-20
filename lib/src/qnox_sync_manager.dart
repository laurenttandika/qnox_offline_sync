import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import 'package:qnox_offline_sync/src/qnox_conflict.dart';
import 'package:qnox_offline_sync/src/models/qnox_sync_status.dart';
import 'package:qnox_offline_sync/src/models/qnox_sync_task.dart';
import 'package:qnox_offline_sync/src/queue/qnox_request_queue.dart';

class QnoxSyncManager {
  final Dio dio;
  final QnoxRequestQueue queue;
  final String baseUrl;
  final QnoxConflictStrategy conflictStrategy;
  final QnoxMergeResolver? mergeResolver;

  final _statusCtrl = StreamController<QnoxSyncStatus>.broadcast();
  StreamSubscription? _connSub;
  final _log = Logger('QnoxSync');

  Stream<QnoxSyncStatus> get onStatus => _statusCtrl.stream;

  QnoxSyncManager({
    required this.dio,
    required this.queue,
    required this.baseUrl,
    this.conflictStrategy = QnoxConflictStrategy.clientWins,
    this.mergeResolver,
  });

  Future<void> start() async {
    _status(QnoxSyncPhase.checkingConnectivity);
    _connSub = Connectivity().onConnectivityChanged.listen((_) async {
      await sync();
    });
    await sync();
  }

  Future<void> stop() async {
    await _connSub?.cancel();
  }

  /// Run a sync cycle: drains due tasks with retry/backoff & conflict handling.
  Future<void> sync() async {
    _status(QnoxSyncPhase.syncing);
    while (true) {
      final tasks = await queue.due(limit: 20);
      if (tasks.isEmpty) break;

      for (final t in tasks) {
        try {
          await _dispatch(t);
          await queue.success(t);
        } on _QnoxRetryableException {
          await queue.retryLater(t);
        } on _QnoxConflictException catch (e) {
          final resolved = await _resolveConflict(t, e);
          if (resolved) {
            await queue.success(t);
          } else {
            await queue.retryLater(t);
          }
        } catch (e, st) {
          _log.warning(
            'Non-retryable error for ${t.method} ${t.path}: $e',
            e,
            st,
          );
          // Conservative fallback: retry later (can be adjusted if needed)
          await queue.retryLater(t);
        }
      }
    }
    final pending = await queue.pending();
    _status(QnoxSyncPhase.idle, pending: pending);
  }

  Future<void> _dispatch(QnoxSyncTask t) async {
    try {
      await dio.request(
        _url(t.path),
        data: t.data,
        options: Options(method: t.method, headers: t.headers),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;

      // No response (offline, DNS), timeouts etc. -> retryable
      if (code == 0) throw _QnoxRetryableException();

      // Server errors / throttling -> retryable
      if (code >= 500 || code == 429) throw _QnoxRetryableException();

      // Versioning / ETag / business conflicts
      if (code == 409 || code == 412) throw _QnoxConflictException(e);

      // 4xx other than above: not retryable; let caller decide (we rethrow)
      rethrow;
    }
  }

  Future<bool> _resolveConflict(
    QnoxSyncTask t,
    _QnoxConflictException e,
  ) async {
    switch (conflictStrategy) {
      case QnoxConflictStrategy.clientWins:
        try {
          await dio.request(
            _url(t.path),
            data: t.data,
            options: Options(method: t.method, headers: t.headers),
          );
          return true;
        } on DioException {
          return false;
        }

      case QnoxConflictStrategy.serverWins:
        // Drop local change and move on.
        return true;

      case QnoxConflictStrategy.merge:
        if (mergeResolver == null) return false;
        try {
          final serverRes = await dio.get(_url(t.path));
          final server = (serverRes.data as Map).cast<String, dynamic>();
          final merged = await mergeResolver!(
            local: t.data ?? {},
            server: server,
          );
          await dio.request(
            _url(t.path),
            data: merged,
            options: Options(method: t.method, headers: t.headers),
          );
          return true;
        } catch (_) {
          return false;
        }
    }
  }

  String _url(String path) {
    // Allow absolute; otherwise join base + path cleanly
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final b = baseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.replaceFirst(RegExp(r'^/'), '');
    return '$b/$p';
  }

  void _status(QnoxSyncPhase p, {int? pending, String? message}) async {
    final count = pending ?? await queue.pending();
    _statusCtrl.add(QnoxSyncStatus(p, pending: count, message: message));
  }
}

class _QnoxRetryableException implements Exception {}

class _QnoxConflictException implements Exception {
  final DioException source;
  _QnoxConflictException(this.source);
}
