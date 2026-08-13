import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:todos_app/core/storage/local_storage_service.dart';
import 'package:todos_app/core/storage/secure_key_store.dart';
import 'package:todos_app/features/auth/data/auth_session_repository.dart';
import 'package:todos_app/features/encryption/data/vault_service.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/settings/data/settings_repository.dart';
import 'package:todos_app/features/settings/domain/privacy_security_status.dart';
import 'package:todos_app/features/settings/presentation/privacy_security_screen.dart';
import 'package:todos_app/features/settings/presentation/settings_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('privacy_settings_test_');
    Hive.init(tempDir.path);
    await NotesRepository.instance.initWithBox(
      await Hive.openBox<Map>('notes_privacy_test'),
    );
    await SettingsRepository.instance.initWithBox(
      await Hive.openBox('settings'),
    );
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('privacy summary when logged out', () {
    expect(
      privacySecuritySettingsSummary(authenticated: false),
      PrivacySecurityCopy.sectionCaption,
    );
    expect(privacySecuritySettingsTrailing(authenticated: false), 'Local');
  });

  testWidgets('settings shows dedicated privacy and security section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          repository: NotesRepository.instance,
          settings: SettingsRepository.instance,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacidad y seguridad'), findsWidgets);
    expect(find.text(AccountSyncCopy.sectionCaption), findsWidgets);
    expect(find.text(PrivacySecurityCopy.sectionCaption), findsWidgets);
    expect(find.text('Local'), findsWidgets);
  });

  testWidgets('privacy screen shows login prompt when logged out', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacySecurityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local'), findsWidgets);
    expect(find.text(AccountSyncCopy.loginTitle), findsOneWidget);
    expect(find.text('Almacenamiento local'), findsOneWidget);
    expect(find.text('Sin cifrar'), findsOneWidget);
  });

  testWidgets('privacy screen shows local encryption when LDEK is ready', (
    tester,
  ) async {
    await LocalStorageService.instance.debugReset();
    await LocalStorageService.instance.init(store: MemorySecureKeyStore());

    await tester.pumpWidget(
      const MaterialApp(home: PrivacySecurityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cifrado'), findsOneWidget);
    expect(
      find.textContaining('Cerrar sesión no los borra'),
      findsOneWidget,
    );
    expect(
      privacySecuritySettingsSummary(authenticated: false),
      PrivacySecurityCopy.sectionCaption,
    );

    await LocalStorageService.instance.debugReset();
  });

  testWidgets('privacy screen offers recovery regeneration when vault ready', (
    tester,
  ) async {
    final secure = _MemorySessionStore();
    await AuthSessionRepository.instance.initWithStores(
      secureStore: secure,
      legacyStore: _MemorySessionStore(),
    );
    await AuthSessionRepository.instance.save(
      accessToken: 'demo-access',
      refreshToken: 'demo-refresh',
      expiresInSeconds: 86400,
      email: 'maria@wodo.app',
    );
    VaultService.instance.debugOverrideCloudState(markVaultReady: true);

    await tester.pumpWidget(
      const MaterialApp(home: PrivacySecurityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Regenerar código de recuperación'), findsOneWidget);
    expect(find.text('Proteger mis datos'), findsNothing);
    expect(find.text('Protegido'), findsOneWidget);

    await AuthSessionRepository.instance.clear();
    VaultService.instance.debugOverrideCloudState(
      accountEncryptionEnabled: false,
      clearDek: true,
    );
  });
}

class _MemorySessionStore implements AuthSessionStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
