import 'package:meta/meta.dart';

@immutable
class QnoxSyncTask {
  final String id; // uuid
  final String method; // GET/POST/PUT/PATCH/DELETE (mutations use non-GET)
  final String path; // "/orders/123"
  final Map<String, dynamic>? data;
  final Map<String, String>? headers;
  final DateTime createdAt;
  final int retries;
  final DateTime nextAttemptAt;

  const QnoxSyncTask({
    required this.id,
    required this.method,
    required this.path,
    this.data,
    this.headers,
    required this.createdAt,
    required this.retries,
    required this.nextAttemptAt,
  });

  QnoxSyncTask copyWith({
    String? id,
    String? method,
    String? path,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    DateTime? createdAt,
    int? retries,
    DateTime? nextAttemptAt,
  }) => QnoxSyncTask(
    id: id ?? this.id,
    method: method ?? this.method,
    path: path ?? this.path,
    data: data ?? this.data,
    headers: headers ?? this.headers,
    createdAt: createdAt ?? this.createdAt,
    retries: retries ?? this.retries,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'method': method,
    'path': path,
    'data': data,
    'headers': headers,
    'createdAt': createdAt.toIso8601String(),
    'retries': retries,
    'nextAttemptAt': nextAttemptAt.toIso8601String(),
  };

  factory QnoxSyncTask.fromMap(Map<String, dynamic> m) => QnoxSyncTask(
    id: m['id'] as String,
    method: m['method'] as String,
    path: m['path'] as String,
    data: (m['data'] as Map?)?.cast<String, dynamic>(),
    headers: (m['headers'] as Map?)?.cast<String, String>(),
    createdAt: DateTime.parse(m['createdAt'] as String),
    retries: m['retries'] as int,
    nextAttemptAt: DateTime.parse(m['nextAttemptAt'] as String),
  );
}
