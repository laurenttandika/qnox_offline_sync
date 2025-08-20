import 'package:uuid/uuid.dart';

/// Represents a queued mutation to be synced later.
class QnoxSyncTask {
  final String id;
  final String method; // POST / PUT / PATCH / DELETE
  final String path;
  final Map<String, dynamic>? data;
  final Map<String, String>? headers;

  final int attempts;
  final DateTime nextAttemptAt;
  final DateTime createdAt;

  QnoxSyncTask({
    required this.id,
    required this.method,
    required this.path,
    this.data,
    this.headers,
    this.attempts = 0,
    DateTime? nextAttemptAt,
    DateTime? createdAt,
  }) : nextAttemptAt = nextAttemptAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  /// Factory for creating a new task.
  factory QnoxSyncTask.newTask({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) {
    return QnoxSyncTask(
      id: const Uuid().v4(),
      method: method.toUpperCase(),
      path: path,
      data: data,
      headers: headers,
    );
  }

  QnoxSyncTask copyWith({
    String? id,
    String? method,
    String? path,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    int? attempts,
    DateTime? nextAttemptAt,
    DateTime? createdAt,
  }) {
    return QnoxSyncTask(
      id: id ?? this.id,
      method: method ?? this.method,
      path: path ?? this.path,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'path': path,
    'data': data,
    'headers': headers,
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory QnoxSyncTask.fromJson(Map<String, dynamic> json) => QnoxSyncTask(
    id: json['id'] as String,
    method: json['method'] as String,
    path: json['path'] as String,
    data: json['data'] != null
        ? Map<String, dynamic>.from(json['data'] as Map)
        : null,
    headers: json['headers'] != null
        ? Map<String, String>.from(json['headers'] as Map)
        : null,
    attempts: json['attempts'] as int? ?? 0,
    nextAttemptAt:
        DateTime.tryParse(json['nextAttemptAt'] ?? '') ?? DateTime.now(),
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );
}
