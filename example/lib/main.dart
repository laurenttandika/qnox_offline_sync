import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:qnox_offline_sync/qnox_offline_sync.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  QnoxSync? sync;
  String status = 'Starting...';
  String lastOutput = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // For public demo, use jsonplaceholder (no auth required)
    final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'))
      ..interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));

    sync = await QnoxSync.create(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      dio: dio,
      // If you test with your own API requiring auth, uncomment and implement:
      // authTokenProvider: () async => await SecureStorage.read('access_token'),
      // refreshToken: () async => await AuthService.refresh(),
    );

    sync!.onSyncStatus.listen((s) {
      if (!mounted) return;
      setState(() => status = s.toString());
    });

    setState(() {});
  }

  Future<void> _safeCall(Future<void> Function() fn) async {
    try {
      await fn();
    } on DioException catch (e) {
      setState(() => lastOutput =
          'DioException: ${e.response?.statusCode} ${e.response?.statusMessage}\n${e.response?.data}');
    } catch (e) {
      setState(() => lastOutput = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Qnox Offline Sync Demo')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $status'),
              const SizedBox(height: 12),

              // Public GET that should always work
              ElevatedButton(
                onPressed: () => _safeCall(() async {
                  final res = await sync!.get('/posts/1', cacheFirst: true);
                  setState(() => lastOutput = 'GET OK\n${res.data}');
                }),
                child: const Text('GET /posts/1 (cacheFirst)'),
              ),
              const SizedBox(height: 8),

              // Public POST: jsonplaceholder accepts and returns 201
              ElevatedButton(
                onPressed: () => _safeCall(() async {
                  final res = await sync!.post('/posts', data: {
                    'title': 'hello',
                    'body': 'world',
                    'userId': 1,
                  }, offlineQueue: false); // explicit: fail fast on 4xx
                  setState(() => lastOutput = 'POST OK\n${res?.data}');
                }),
                child: const Text('POST /posts (no auth)'),
              ),
              const SizedBox(height: 8),

              // Simulate 403 if you point to your own API without token
              ElevatedButton(
                onPressed: () => _safeCall(() async {
                  // Change baseUrl + enable authTokenProvider in _init() to avoid 403s.
                  await sync!.post('/protected/resource', data: {'x': 1});
                  setState(() => lastOutput =
                      'Queued or sent (check logs). If 403, verify Authorization header and route policy.');
                }),
                child: const Text('POST /protected/resource (expect 403 without auth)'),
              ),
              const SizedBox(height: 12),

              const Text('Output:'),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    lastOutput,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}