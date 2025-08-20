# qnox_offline_sync

Offline-first sync for Flutter. Cache GETs, queue mutations while offline, then auto-sync on reconnect with retries, conflict resolution, and pluggable storage backends.

## Features
- Local cache with TTL
- Durable mutation queue (POST/PUT/PATCH/DELETE)
- Auto sync with exponential backoff
- Pluggable conflict strategies (client-wins / server-wins / merge)
- Streams for sync status
- Extensible storage backends (default: Sembast)

## Quick start
```dart
final sync = await QnoxSync.create(
  baseUrl: 'https://api.example.com',
  authTokenProvider: () async => await SecureStorage.read('access_token'),
  refreshToken: () async {
    final ok = await AuthService.refresh();
    return ok;
  },
);

final res = await sync.get('/users', cacheFirst: true);
await sync.post('/orders', data: order.toJson()); // queued if offline
```

## Storage backends
By default, `qnox_offline_sync` uses **Sembast** as the offline queue and cache store. 

You can also provide your own storage engine by implementing the `QnoxLocalStore` interface:

```dart
class MyCustomStore implements QnoxLocalStore {
  @override
  Future<void> init() async { /* init db */ }

  @override
  Future<void> enqueue(QnoxSyncTask task) async { /* save task */ }

  @override
  Future<List<QnoxSyncTask>> dueTasks({int limit = 20}) async { /* return tasks */ }

  @override
  Future<void> updateTask(QnoxSyncTask task) async { /* update */ }

  @override
  Future<void> removeTask(String id) async { /* delete */ }

  @override
  Future<int> pendingCount() async { /* count */ }

  @override
  Future<void> putCache(String cacheKey, Map<String, dynamic> payload, {required Duration ttl}) async { /* cache */ }

  @override
  Future<Map<String, dynamic>?> getCache(String cacheKey) async { /* fetch cache */ }

  @override
  Future<void> purgeExpiredCache() async { /* cleanup */ }
}
```

Then pass it when creating `QnoxSync`:

```dart
final sync = await QnoxSync.create(
  baseUrl: 'https://api.example.com',
  store: MyCustomStore(),
);
```

## Background sync
Use `workmanager` (Android) or `background_fetch` (iOS) to periodically call into your app and run `await sync.sync()`.

## Roadmap
- Built-in background schedulers (platform channels)
- Batching & delta sync helpers
- Encryption at rest
- Web support via sembast_web
