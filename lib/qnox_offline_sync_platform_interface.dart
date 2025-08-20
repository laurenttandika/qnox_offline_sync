import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'qnox_offline_sync_method_channel.dart';

abstract class QnoxOfflineSyncPlatform extends PlatformInterface {
  QnoxOfflineSyncPlatform() : super(token: _token);

  static final Object _token = Object();

  static QnoxOfflineSyncPlatform _instance = MethodChannelQnoxOfflineSync();

  /// The default instance of [QnoxOfflineSyncPlatform] to use.
  static QnoxOfflineSyncPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// class that extends [QnoxOfflineSyncPlatform].
  static set instance(QnoxOfflineSyncPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Example method: get platform version
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
}