import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:todos_app/features/sync/data/device_identity.dart';

void main() {
  setUp(() async {
    Hive.init('./test/tmp_device_identity');
    await DeviceIdentity.instance.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('generates a stable appUserId per install', () async {
    final first = DeviceIdentity.instance.appUserId;
    await DeviceIdentity.instance.init();
    expect(DeviceIdentity.instance.appUserId, first);
  });

  test('syncEnabled defaults to true and can be toggled', () async {
    expect(DeviceIdentity.instance.syncEnabled, isTrue);
    await DeviceIdentity.instance.setSyncEnabled(false);
    expect(DeviceIdentity.instance.syncEnabled, isFalse);
  });
}
