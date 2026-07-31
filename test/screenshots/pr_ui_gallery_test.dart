@Tags(['screenshot-gallery'])
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:todos_app/app/adaptive_app_shell.dart';
import 'package:todos_app/core/theme/theme.dart';
import 'package:todos_app/features/auth/data/auth_session_repository.dart';
import 'package:todos_app/features/auth/presentation/auth_screen.dart';
import 'package:todos_app/features/encryption/data/vault_service.dart';
import 'package:todos_app/features/encryption/presentation/link_device_gate.dart';
import 'package:todos_app/features/encryption/presentation/recovery_code_screen.dart';
import 'package:todos_app/features/encryption/presentation/unlock_recovery_screen.dart';
import 'package:todos_app/features/home/presentation/home_screen.dart';
import 'package:todos_app/features/notes/data/day_entries_repository.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/pairing/data/pairing_service.dart';
import 'package:todos_app/features/pairing/presentation/approve_pairing_screen.dart';
import 'package:todos_app/features/pairing/presentation/qr_login_screen.dart';
import 'package:todos_app/features/settings/data/settings_repository.dart';
import 'package:todos_app/features/settings/presentation/settings_screen.dart';

const _out = '../../../opt/cursor/artifacts/screenshots/pr-ui-gallery';
const _desktop = Size(1280, 900);
const _mobile = Size(480, 900);

final _previewPairing = PairingStart(
  pairingId: 'demo-pairing',
  displayCode: 'WB2DELHZ',
  pollToken: 'demo-token',
  expiresAt: DateTime.now().add(const Duration(minutes: 3)),
  qrPayload: {
    'type': 'wodo_pairing',
    'code': 'WB2DELHZ',
    'pairingId': 'demo-pairing',
  },
);

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    Directory('/opt/cursor/artifacts/screenshots/pr-ui-gallery').createSync(recursive: true);
    hiveDir = Directory.systemTemp.createTempSync('wodo_gallery_hive_');
    Hive.init(hiveDir.path);
    await NotesRepository.instance.initWithBox(
      await Hive.openBox<Map>('notes_gallery'),
    );
    await DayEntriesRepository.instance.initWithBox(
      await Hive.openBox<Map>('day_entries_gallery'),
    );
    await SettingsRepository.instance.initWithBox(
      await Hive.openBox('settings_gallery'),
    );
    final secure = _MemorySessionStore();
    await AuthSessionRepository.instance.initWithStores(
      secureStore: secure,
      legacyStore: _MemorySessionStore(),
    );
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (hiveDir.existsSync()) await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await AuthSessionRepository.instance.clear();
    VaultService.instance.debugOverrideCloudState(
      accountEncryptionEnabled: false,
      deviceVaultState: 'none',
      clearDek: true,
    );
    debugDefaultTargetPlatformOverride = null;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      FlutterError.presentError(details);
    };
  });

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget child,
    Size size,
  ) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: child),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/$name.png'),
    );
  }

  testWidgets('01 login desktop', (tester) async {
    await golden(tester, '01_login_desktop', const AuthScreen(), _desktop);
  });

  testWidgets('02 login mobile', (tester) async {
    await golden(tester, '02_login_mobile', const AuthScreen(), _mobile);
  });

  testWidgets('03 register desktop', (tester) async {
    await tester.binding.setSurfaceSize(_desktop);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const AuthScreen()),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Crear una cuenta nueva'));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/03_register_desktop.png'),
    );
  });

  testWidgets('04 register mobile', (tester) async {
    await tester.binding.setSurfaceSize(_mobile);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const AuthScreen()),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Crear una cuenta nueva'));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/04_register_mobile.png'),
    );
  });

  testWidgets('05 qr pairing desktop', (tester) async {
    await golden(
      tester,
      '05_qr_pairing_desktop',
      QrLoginScreen(previewPairing: _previewPairing),
      _desktop,
    );
  });

  testWidgets('06 qr pairing mobile', (tester) async {
    await golden(
      tester,
      '06_qr_pairing_mobile',
      QrLoginScreen(previewPairing: _previewPairing),
      _mobile,
    );
  });

  testWidgets('07 approve pairing manual desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await golden(tester, '07_approve_pairing_desktop', const ApprovePairingScreen(), _desktop);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('08 approve pairing scanner mobile', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await golden(tester, '08_approve_pairing_mobile', const ApprovePairingScreen(), _mobile);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('09 recovery code desktop', (tester) async {
    await golden(
      tester,
      '09_recovery_code_desktop',
      const RecoveryCodeScreen(recoveryCode: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX'),
      _desktop,
    );
  });

  testWidgets('10 recovery code mobile', (tester) async {
    await golden(
      tester,
      '10_recovery_code_mobile',
      const RecoveryCodeScreen(recoveryCode: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX'),
      _mobile,
    );
  });

  testWidgets('11 unlock recovery desktop', (tester) async {
    await golden(tester, '11_unlock_recovery_desktop', const UnlockRecoveryScreen(), _desktop);
  });

  testWidgets('12 unlock recovery mobile', (tester) async {
    await golden(tester, '12_unlock_recovery_mobile', const UnlockRecoveryScreen(), _mobile);
  });

  testWidgets('13 link device gate desktop', (tester) async {
    VaultService.instance.debugOverrideCloudState(
      accountEncryptionEnabled: true,
      deviceVaultState: 'none',
      clearDek: true,
    );
    await golden(tester, '13_link_device_gate_desktop', const LinkDeviceGate(), _desktop);
  });

  testWidgets('14 link device revoked mobile', (tester) async {
    VaultService.instance.debugOverrideCloudState(
      accountEncryptionEnabled: true,
      deviceVaultState: 'revoked',
      clearDek: true,
    );
    await golden(tester, '14_link_device_revoked_mobile', const LinkDeviceGate(), _mobile);
  });

  testWidgets('15 settings logged out desktop', (tester) async {
    await golden(
      tester,
      '15_settings_logged_out_desktop',
      SettingsScreen(
        repository: NotesRepository.instance,
        settings: SettingsRepository.instance,
      ),
      _desktop,
    );
  });

  testWidgets('16 settings security off desktop', (tester) async {
    await _saveDemoSession();
    await golden(
      tester,
      '16_settings_security_off_desktop',
      SettingsScreen(
        repository: NotesRepository.instance,
        settings: SettingsRepository.instance,
      ),
      _desktop,
    );
  });

  testWidgets('17 settings security off mobile', (tester) async {
    await _saveDemoSession();
    await golden(
      tester,
      '17_settings_security_off_mobile',
      SettingsScreen(
        repository: NotesRepository.instance,
        settings: SettingsRepository.instance,
      ),
      _mobile,
    );
  });

  testWidgets('18 settings link device desktop', (tester) async {
    await _saveDemoSession();
    VaultService.instance.debugOverrideCloudState(
      accountEncryptionEnabled: true,
      deviceVaultState: 'none',
      clearDek: true,
    );
    await golden(
      tester,
      '18_settings_link_device_desktop',
      SettingsScreen(
        repository: NotesRepository.instance,
        settings: SettingsRepository.instance,
      ),
      _desktop,
    );
  });

  testWidgets('19 settings e2ee active mobile', (tester) async {
    await _saveDemoSession();
    VaultService.instance.debugOverrideCloudState(markVaultReady: true);
    await golden(
      tester,
      '19_settings_e2ee_active_mobile',
      SettingsScreen(
        repository: NotesRepository.instance,
        settings: SettingsRepository.instance,
      ),
      _mobile,
    );
  });

  testWidgets('20 home desktop', (tester) async {
    await golden(
      tester,
      '20_home_desktop',
      HomeScreen(repository: NotesRepository.instance),
      _desktop,
    );
  });

  testWidgets('21 home mobile', (tester) async {
    await golden(
      tester,
      '21_home_mobile',
      HomeScreen(repository: NotesRepository.instance),
      _mobile,
    );
  });

  testWidgets('22 shell desktop', (tester) async {
    await golden(
      tester,
      '22_shell_desktop',
      AdaptiveAppShell(
        repository: NotesRepository.instance,
        settings: SettingsRepository.instance,
      ),
      _desktop,
    );
  });

  testWidgets('23 shell mobile', (tester) async {
    await golden(
      tester,
      '23_shell_mobile',
      AdaptiveAppShell(
        repository: NotesRepository.instance,
        settings: SettingsRepository.instance,
      ),
      _mobile,
    );
  });
}

Future<void> _saveDemoSession() async {
  await AuthSessionRepository.instance.save(
    accessToken: 'demo-access',
    refreshToken: 'demo-refresh',
    expiresInSeconds: 86400,
    email: 'maria@wodo.app',
  );
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
