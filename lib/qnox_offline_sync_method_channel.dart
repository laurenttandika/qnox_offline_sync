import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'qnox_offline_sync_platform_interface.dart';

/// The default MethodChannel-based implementation of [QnoxOfflineSyncPlatform].
class MethodChannelQnoxOfflineSync extends QnoxOfflineSyncPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('qnox_offline_sync');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}