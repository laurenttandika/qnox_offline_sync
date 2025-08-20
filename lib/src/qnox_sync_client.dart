import 'dart:async';
import 'package:dio/dio.dart';
import 'package:qnox_offline_sync/src/models/qnox_sync_status.dart';
import 'package:qnox_offline_sync/src/models/qnox_sync_task.dart'; // ← add this
import 'package:qnox_offline_sync/src/qnox_conflict.dart';
import 'package:qnox_offline_sync/src/qnox_sync_manager.dart';
import 'package:qnox_offline_sync/src/queue/qnox_request_queue.dart';
import 'package:qnox_offline_sync/src/storage/qnox_local_store.dart';
import 'package:qnox_offline_sync/src/storage/qnox_sembast_store.dart';

class QnoxSync {
  final String baseUrl;
  final Dio _dio;
  final QnoxLocalStore _store;
  late final QnoxRequestQueue _queue;
  late final QnoxSyncManager _manager;

  // Auth & UA hooks
  final Future<String?> Function()? _authTokenProvider;
  final Future<bool> Function()? _refreshToken;
  final String? _customUserAgent;

  QnoxSync._(
    this.baseUrl,
    this._dio,
    this._store,
    this._authTokenProvider,
    this._refreshToken,
    this._customUserAgent,
  );

  static Future<QnoxSync> create({
    required String baseUrl,
    Dio? dio,
    QnoxLocalStore? store,
    QnoxConflictStrategy conflictStrategy = QnoxConflictStrategy.clientWins,
    QnoxMergeResolver? mergeResolver,
    Future<String?> Function()? authTokenProvider,
    Future<bool> Function()? refreshToken,
    String? userAgent,
  }) async {
    final client = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

    if (userAgent != null && userAgent.isNotEmpty) {
      client.options.headers['User-Agent'] = userAgent;
    }

    if (authTokenProvider != null) {
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await authTokenProvider();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );
    }

    if (refreshToken != null) {
      client.interceptors.add(
        InterceptorsWrapper(
          onError: (DioException err, ErrorInterceptorHandler handler) async {
            final response = err.response;
            final req = err.requestOptions;

            final alreadyRetried = req.extra['__qnox_retried'] == true;
            if (response?.statusCode == 401 && !alreadyRetried) {
              final ok = await refreshToken();
              if (ok) {
                if (authTokenProvider != null) {
                  final token = await authTokenProvider();
                  if (token != null && token.isNotEmpty) {
                    req.headers['Authorization'] = 'Bearer $token';
                  }
                }
                req.extra['__qnox_retried'] = true;
                try {
                  final replay = await client.fetch<dynamic>(req);
                  return handler.resolve(replay);
                } catch (_) {}
              }
            }
            handler.next(err);
          },
        ),
      );
    }

    final s = store ?? QnoxSembastStore();
    await s.init();

    final u = QnoxSync._(
      baseUrl,
      client,
      s,
      authTokenProvider,
      refreshToken,
      userAgent,
    );
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

  Stream<QnoxSyncStatus> get onSyncStatus => _manager.onStatus;

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
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final isNetwork = code == 0;
      final retryable = isNetwork || code >= 500 || code == 429;

      if (offlineQueue && retryable) {
        // FIX: construct a task and enqueue it
        final task = QnoxSyncTask.newTask(
          method: method,
          path: path,
          data: data,
          headers: headers,
        );
        await _queue.enqueue(task);
        return null;
      }

      rethrow;
    }
  }

  String _cacheKey(String path, Map<String, dynamic>? query) {
    final parts = <String>[path];
    if (query != null && query.isNotEmpty) {
      final entries = query.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      parts.add(entries.map((e) => '${e.key}=${e.value}').join('&'));
    }
    return parts.join('|');
  }

  Future<void> dispose() async {
    await _manager.stop();
    await _store.dispose();
  }
}
