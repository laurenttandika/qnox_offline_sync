// ----- directives (must come before any declarations)
import 'package:qnox_offline_sync/qnox_offline_sync_platform_interface.dart';

export 'src/qnox_sync_client.dart';
export 'src/qnox_sync_manager.dart';
export 'src/qnox_conflict.dart';
export 'src/models/qnox_sync_status.dart';
export 'src/models/qnox_sync_task.dart';
export 'src/queue/qnox_request_queue.dart';

// Recommended: only expose the storage interface, not default impl
export 'src/storage/qnox_local_store.dart';

// ----- declarations
/// Simple platform interface facade (e.g., for native version, hooks)
class QnoxOfflineSync {
  Future<String?> getPlatformVersion() {
    return QnoxOfflineSyncPlatform.instance.getPlatformVersion();
  }
}