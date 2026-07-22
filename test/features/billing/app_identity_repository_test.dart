import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:todos_app/features/billing/data/app_identity_repository.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  final repository = AppIdentityRepository.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('app_identity_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('identity');
    await repository.initWithBox(box);
  });

  tearDown(() async {
    await repository.clear();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('creates a UUID and keeps it across initializations', () async {
    final generated = repository.appUserId;
    expect(Uuid.isValidUUID(fromString: generated), isTrue);

    await repository.initWithBox(box);
    expect(repository.appUserId, generated);
  });

  test('uses a valid cross-platform override', () async {
    const sharedId = '11111111-2222-4333-8444-555555555555';
    final storedLocalId = repository.appUserId;

    await repository.initWithBox(box, overrideAppUserId: sharedId);

    expect(repository.appUserId, sharedId);
    expect(box.get('app_user_id'), storedLocalId);
  });

  test('rejects an override that is not a UUID', () async {
    expect(
      () => repository.initWithBox(box, overrideAppUserId: 'user@email.com'),
      throwsArgumentError,
    );
  });
}
