import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/settings/data/settings_repository.dart';
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
      'Inicia sesión para activar',
    );
    expect(privacySecuritySettingsTrailing(authenticated: false), isNull);
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
    expect(find.textContaining('Inicia sesión para activar'), findsOneWidget);
  });

  testWidgets('privacy screen shows login prompt when logged out', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacySecurityScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modo local'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
