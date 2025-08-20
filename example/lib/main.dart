import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    sync = await QnoxSync.create(
      baseUrl: 'https://jsonplaceholder.typicode.com',
    );
    sync!.onSyncStatus.listen((s) => setState(() => status = s.toString()));
    setState(() {});
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
              ElevatedButton(
                onPressed: () async {
                  final res = await sync!.get('/posts/1', cacheFirst: true);
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) =>
                        AlertDialog(content: Text(res.data.toString())),
                  );
                },
                child: const Text('GET (cacheFirst)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  // This will queue if offline
                  await sync!.post(
                    '/posts',
                    data: {'title': 'hello', 'body': 'world'},
                  );
                },
                child: const Text('POST (queue if offline)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
