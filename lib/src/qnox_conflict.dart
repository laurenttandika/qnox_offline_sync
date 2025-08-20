import 'dart:async';

/// Built-in conflict strategies for update/patch/delete collisions.
enum QnoxConflictStrategy { clientWins, serverWins, merge }

/// User-provided merge resolver when [QnoxConflictStrategy.merge] is chosen.
///
/// Given the latest server payload and the local payload queued offline,
/// return the final document to write back.
typedef QnoxMergeResolver =
    Future<Map<String, dynamic>> Function({
      required Map<String, dynamic> local,
      required Map<String, dynamic> server,
    });
