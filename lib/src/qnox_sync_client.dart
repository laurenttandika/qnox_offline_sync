import 'dart:async';
import 'package:dio/dio.dart';
import 'package:qnox_offline_sync/src/queue/qnox_request_queue.dart';
import 'package:qnox_offline_sync/src/storage/qnox_local_store.dart';
import 'package:qnox_offline_sync/src/storage/qnox_sembast_store.dart';
import 'package:qnox_offline_sync/src/qnox_sync_manager.dart';
import 'package:qnox_offline_sync/src/qnox_conflict.dart';
import 'package:qnox_offline_sync/src/models/qnox_sync_status.dart';

class QnoxSync {
  final String baseUrl;
  final Dio _dio;
  final QnoxLocalStore _store;
  late final QnoxRequestQueue _queue;
  late final QnoxSyncManager _manager;

  QnoxSync._(this.baseUrl, this._dio, this._store);

  static Future<QnoxSync> create({
    required String baseUrl,
    Dio? dio,
    QnoxLocalStore? store,
    QnoxConflictStrategy conflictStrategy = QnoxConflictStrategy.clientWins,
    QnoxMergeResolver? mergeResolver,
  }) async {
    final client = dio ?? Dio(BaseOptions(baseUrl: baseUrl));
    final s = store ?? QnoxSembastStore();
    await s.init();
    final u = QnoxSync._(baseUrl, client, s);
    u._queue = QnoxRequestQueue(s);
    u._manager = QnoxSyncManager(
      dio: client,
      queue: u._queue,
      baseUrl: baseUrl,
      conflictStrategy: conflictStrategy,
      mergeResolver: mergeResolver,
    );
    await u._manager.start();
    return u;
  }

  /// Subscribe to sync status updates
  Stream<QnoxSyncStatus> get onSyncStatus => _manager.onStatus;

  /// GET with optional cache-first behavior.
  Future<Response> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool cacheFirst = false,
    Duration cacheTtl = const Duration(minutes: 10),
  }) async {
    final cacheKey = _cacheKey(path, query);
    if (cacheFirst) {
      final cached = await _store.getCache(cacheKey);
      if (cached != null) {
        return Response(
          data: cached,
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          statusMessage: 'OK (cache)',
        );
      }
    }

    final res = await _dio.get(
      path,
      queryParameters: query,
      options: Options(headers: headers),
    );
    if (res.data is Map<String, dynamic>) {
      await _store.putCache(
        cacheKey,
        (res.data as Map<String, dynamic>),
        ttl: cacheTtl,
      );
    }
    return res;
  }

  /// Queue mutations when offline. If request fails due to network/5xx, it will be queued and retried.
  Future<Response?> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    bool offlineQueue = true,
  }) async {
    return _mutate(
      'POST',
      path,
      data: data,
      headers: headers,
      offlineQueue: offlineQueue,
    );
  }

  Future<Response?> put(
    String path, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    bool offlineQueue = true,
  }) async {
    return _mutate(
      'PUT',
      path,
      data: data,
      headers: headers,
      offlineQueue: offlineQueue,
    );
  }

  Future<Response?> patch(
    String path, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    bool offlineQueue = true,
  }) async {
    return _mutate(
      'PATCH',
      path,
      data: data,
      headers: headers,
      offlineQueue: offlineQueue,
    );
  }

  Future<Response?> delete(
    String path, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    bool offlineQueue = true,
  }) async {
    return _mutate(
      'DELETE',
      path,
      data: data,
      headers: headers,
      offlineQueue: offlineQueue,
    );
  }

  Future<Response?> _mutate(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    required bool offlineQueue,
  }) async {
    try {
      final res = await _dio.request(
        path,
        data: data,
        options: Options(method: method, headers: headers),
      );
      return res;
    } catch (e) {
      if (!offlineQueue) rethrow;
      // Enqueue and return null (fire-and-forget); app can listen to onSyncStatus
      await _queue.enqueue(
        method: method,
        path: path,
        data: data,
        headers: headers,
      );
      return null;
    }
  }

  String _cacheKey(String path, Map<String, dynamic>? query) => [
    path,
    if (query != null)
      query.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  ].join('|');

  Future<void> dispose() async {
    await _manager.stop();
    await _store.dispose();
  }
}
