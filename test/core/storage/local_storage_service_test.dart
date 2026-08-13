import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:todos_app/core/storage/local_storage_service.dart';
import 'package:todos_app/core/storage/secure_key_store.dart';

void main() {
  late Directory tempDir;
  late MemorySecureKeyStore store;

  setUp(() async {
    await LocalStorageService.instance.debugReset();
    tempDir = await Directory.systemTemp.createTemp('local_hive_');
    Hive.init(tempDir.path);
    store = MemorySecureKeyStore();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await LocalStorageService.instance.debugReset();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('init generates a 32-byte LDEK and persists it', () async {
    await LocalStorageService.instance.init(store: store);

    expect(LocalStorageService.instance.isEnabled, isTrue);
    expect(LocalStorageService.instance.debugLdek, hasLength(32));
    expect(store.values[LocalStorageService.ldekStorageKey], isNotEmpty);
  });

  test('init reuses the stored LDEK', () async {
    await LocalStorageService.instance.init(store: store);
    final first = LocalStorageService.instance.debugLdek;
    await LocalStorageService.instance.debugReset();

    await LocalStorageService.instance.init(store: store);
    expect(LocalStorageService.instance.debugLdek, first);
  });

  test('migrates a plaintext notes box and keeps values readable', () async {
    final plain = await Hive.openBox<Map>('notes');
    await plain.put('n1', {'id': 'n1', 'title': 'Comprar pan'});
    await plain.close();

    await LocalStorageService.instance.init(store: store);
    final encrypted = await LocalStorageService.instance.openBox<Map>('notes');
    expect(encrypted.get('n1')?['title'], 'Comprar pan');
    await encrypted.close();

    await expectLater(
      Hive.openBox<Map>('notes', crashRecovery: false),
      throwsA(isA<HiveError>()),
    );

    final again = await LocalStorageService.instance.openBox<Map>('notes');
    expect(again.get('n1')?['title'], 'Comprar pan');
  });

  test('settings box stays plaintext', () async {
    await LocalStorageService.instance.init(store: store);
    final settings = await LocalStorageService.instance.openBox('settings');
    await settings.put('themeMode', 'dark');
    await settings.close();

    final reopened = await Hive.openBox('settings');
    expect(reopened.get('themeMode'), 'dark');
  });

  test('attachment blobs survive encryption roundtrip', () async {
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final plain = await Hive.openBox<dynamic>('attachment_blobs');
    await plain.put('img1', bytes);
    await plain.close();

    await LocalStorageService.instance.init(store: store);
    final encrypted = await LocalStorageService.instance.openBox<dynamic>(
      'attachment_blobs',
    );
    expect(encrypted.get('img1'), bytes);
  });

  test(
    'logout-equivalent reset of service does not delete LDEK in store',
    () async {
      await LocalStorageService.instance.init(store: store);
      final stored = store.values[LocalStorageService.ldekStorageKey];
      await LocalStorageService.instance.debugReset();
      expect(store.values[LocalStorageService.ldekStorageKey], stored);
    },
  );

  test('enable app lock removes raw LDEK and unlock restores it', () async {
    await LocalStorageService.instance.init(store: store);
    final original = LocalStorageService.instance.debugLdek;
    await LocalStorageService.instance.enableAppLock('2580');

    expect(LocalStorageService.instance.isAppLockEnabled, isTrue);
    expect(LocalStorageService.instance.isSessionUnlocked, isTrue);
    expect(store.values[LocalStorageService.ldekStorageKey], isNull);
    expect(store.values[LocalStorageService.ldekWrapStorageKey], isNotEmpty);

    await LocalStorageService.instance.debugReset();
    await LocalStorageService.instance.init(store: store);
    expect(LocalStorageService.instance.needsUnlock, isTrue);
    expect(LocalStorageService.instance.debugLdek, isNull);
    expect(store.values[LocalStorageService.ldekStorageKey], isNull);

    await expectLater(
      LocalStorageService.instance.openBox<Map>('notes'),
      throwsA(isA<StateError>()),
    );

    expect(await LocalStorageService.instance.unlockWithPin('0000'), isFalse);
    expect(await LocalStorageService.instance.unlockWithPin('2580'), isTrue);
    expect(LocalStorageService.instance.debugLdek, original);

    final box = await LocalStorageService.instance.openBox<Map>('notes');
    await box.put('n1', {'id': 'n1', 'title': 'Tras el PIN'});
    expect(box.get('n1')?['title'], 'Tras el PIN');
  });

  test('disable app lock restores raw LDEK', () async {
    await LocalStorageService.instance.init(store: store);
    final original = LocalStorageService.instance.debugLdek;
    await LocalStorageService.instance.enableAppLock('9999');
    expect(await LocalStorageService.instance.disableAppLock('1111'), isFalse);
    expect(await LocalStorageService.instance.disableAppLock('9999'), isTrue);
    expect(LocalStorageService.instance.isAppLockEnabled, isFalse);
    expect(store.values[LocalStorageService.ldekStorageKey], isNotEmpty);
    expect(store.values[LocalStorageService.ldekWrapStorageKey], isNull);
    expect(LocalStorageService.instance.debugLdek, original);
  });

  test('forgotten PIN wipes encrypted boxes and starts a new LDEK', () async {
    await LocalStorageService.instance.init(store: store);
    final box = await LocalStorageService.instance.openBox<Map>('notes');
    await box.put('gone', {'id': 'gone', 'title': 'secreto'});
    await LocalStorageService.instance.enableAppLock('4321');
    await box.close();

    await LocalStorageService.instance.debugReset();
    await LocalStorageService.instance.init(store: store);
    await LocalStorageService.instance.resetAfterForgottenPin();

    expect(LocalStorageService.instance.isAppLockEnabled, isFalse);
    expect(LocalStorageService.instance.isSessionUnlocked, isTrue);
    final fresh = await LocalStorageService.instance.openBox<Map>('notes');
    expect(fresh.get('gone'), isNull);
  });
}
