enum QnoxSyncPhase { idle, checkingConnectivity, syncing, backoff, error }

class QnoxSyncStatus {
  final QnoxSyncPhase phase;
  final int pending;
  final String? message;

  const QnoxSyncStatus(this.phase, {this.pending = 0, this.message});

  @override
  String toString() =>
      'QnoxSyncStatus(phase: $phase, pending: $pending, message: $message)';
}
