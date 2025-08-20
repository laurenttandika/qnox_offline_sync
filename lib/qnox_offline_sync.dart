import 'qnox_offline_sync_platform_interface.dart';

class QnoxOfflineSync {
  Future<String?> getPlatformVersion() {
    return QnoxOfflineSyncPlatform.instance.getPlatformVersion();
  }
}

// ===== Offline Sync Engine Exports =====
export 'src/qnox_sync_client.dart';
export 'src/qnox_sync_manager.dart';
export 'src/qnox_conflict.dart';
export 'src/models/qnox_sync_status.dart';
export 'src/models/qnox_sync_task.dart';
export 'src/queue/qnox_request_queue.dart';
export 'src/storage/qnox_local_store.dart';
//export 'src/storage/qnox_sembast_store.dart';