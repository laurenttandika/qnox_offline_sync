// lib/src/qnox_conflict.dart

import 'dart:async';

/// Built-in conflict strategies for update/patch/delete collisions during sync.
///
/// - [clientWins]: The locally queued change is forced to the server.
/// - [serverWins]: The server version is accepted; the local change is dropped.
/// - [merge]: A custom resolver merges local + server into a final payload.
enum QnoxConflictStrategy { clientWins, serverWins, merge }

/// Signature for a custom merge resolver used when [QnoxConflictStrategy.merge] is selected.
///
/// Implementations receive the latest server payload and the local (queued) payload,
/// and must return the final document to write back to the server.
///
/// Example:
/// ```dart
/// final merged = await myResolver(local: localDoc, server: serverDoc);
/// ```
typedef QnoxMergeResolver =
    Future<Map<String, dynamic>> Function({
      required Map<String, dynamic> local,
      required Map<String, dynamic> server,
    });
