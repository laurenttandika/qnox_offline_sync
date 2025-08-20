import 'package:flutter_test/flutter_test.dart';
import 'package:qnox_offline_sync/qnox_offline_sync.dart';
import 'package:qnox_offline_sync/qnox_offline_sync_platform_interface.dart';
import 'package:qnox_offline_sync/qnox_offline_sync_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockQnoxOfflineSyncPlatform
    with MockPlatformInterfaceMixin
    implements QnoxOfflineSyncPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final QnoxOfflineSyncPlatform initialPlatform = QnoxOfflineSyncPlatform.instance;

  test('$MethodChannelQnoxOfflineSync is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelQnoxOfflineSync>());
  });

  test('getPlatformVersion', () async {
    QnoxOfflineSync qnoxOfflineSyncPlugin = QnoxOfflineSync();
    MockQnoxOfflineSyncPlatform fakePlatform = MockQnoxOfflineSyncPlatform();
    QnoxOfflineSyncPlatform.instance = fakePlatform;

    expect(await qnoxOfflineSyncPlugin.getPlatformVersion(), '42');
  });
}
