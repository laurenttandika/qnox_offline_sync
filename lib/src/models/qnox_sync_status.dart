/// High-level phases of the sync engine.
enum QnoxSyncPhase {
  idle, // Nothing to do
  checkingConnectivity, // Listening for network changes
  syncing, // Actively processing queued tasks
}

/// Status snapshot emitted by [QnoxSyncManager.onStatus].
class QnoxSyncStatus {
  final QnoxSyncPhase phase;

  /// Number of tasks still pending in the queue.
  final int pending;

  /// Optional human-readable message (e.g., error, progress detail).
  final String? message;

  QnoxSyncStatus(this.phase, {this.pending = 0, this.message});

  @override
  String toString() =>
      'QnoxSyncStatus(phase: $phase, pending: $pending, message: $message)';
}
