import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:todos_app/features/settings/data/settings_repository.dart';
import 'package:todos_app/features/settings/domain/list_background.dart';
import 'package:todos_app/features/settings/presentation/data_backup.dart';
import 'package:todos_app/global/themes/app_colors.dart';

void main() {
  late Directory tempDir;
  late SettingsRepository settings;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_repo_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox(
      'settings_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    settings = SettingsRepository.instance;
    await settings.initWithBox(box);
    await settings.clear();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('themeMode defaults to system and persists', () async {
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.themeModeLabel, 'Sistema');

    await settings.setThemeMode(ThemeMode.dark);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.themeModeLabel, 'Oscuro');

    await settings.setThemeMode(ThemeMode.light);
    expect(settings.themeMode, ThemeMode.light);
  });

  test('listBackgroundId defaults and resolves catalog', () async {
    expect(settings.listBackgroundId, ListBackgrounds.defaultId);
    expect(settings.listBackground.id, ListBackgrounds.defaultId);

    await settings.setListBackgroundId('sakura');
    expect(settings.listBackgroundId, 'sakura');
    expect(settings.listBackground.label, 'Sakura');
    expect(
      settings.listBackground.resolveGradient(Brightness.light),
      isNotNull,
    );
    expect(
      settings.listBackground.resolveGradient(Brightness.dark),
      isNotNull,
    );
  });

  test('showHeatmapDayNumbers defaults to true and persists', () async {
    expect(settings.showHeatmapDayNumbers, isTrue);
    expect(settings.showHeatmapDayNumbersLabel, 'Visibles');

    await settings.setShowHeatmapDayNumbers(false);
    expect(settings.showHeatmapDayNumbers, isFalse);
    expect(settings.showHeatmapDayNumbersLabel, 'Ocultos');

    await settings.setShowHeatmapDayNumbers(true);
    expect(settings.showHeatmapDayNumbers, isTrue);
  });

  test('unknown background id falls back to default', () {
    final option = ListBackgrounds.byId('does_not_exist');
    expect(option.id, ListBackgrounds.defaultId);
  });

  test('peach accent is terracotta, not brand green', () {
    final peach = ListBackgrounds.byId('peach');
    final accent = peach.resolveAccent(Brightness.light);
    expect(accent, const Color(0xFFC45C2A));
    expect(accent, isNot(AppColors.primary));
  });

  test('solid options ship tinted Unsplash assets', () {
    for (final solid in ListBackgrounds.solids) {
      expect(solid.hasAsset, isTrue);
      expect(solid.assetPath, startsWith('assets/images/backgrounds/'));
      expect(solid.lightAccent, isNotNull);
    }
  });

  test('parseNotesBackup accepts wrapped and raw list formats', () {
    final rawList = '''
[
  {
    "id": "1",
    "type": "note",
    "title": "Hola",
    "body": "Mundo",
    "pinned": false,
    "completed": false,
    "createdAt": "2026-07-19T12:00:00.000",
    "updatedAt": "2026-07-19T12:00:00.000"
  }
]
''';
    final wrapped = '''
{
  "version": 1,
  "notes": $rawList
}
''';

    expect(parseNotesBackup(rawList), isNotNull);
    expect(parseNotesBackup(rawList)!.length, 1);
    expect(parseNotesBackup(wrapped)!.first['id'], '1');
  });

  test('parseNotesBackup rejects invalid payloads', () {
    expect(parseNotesBackup('not-json'), isNull);
    expect(parseNotesBackup('{"foo":1}'), isNull);
    expect(parseNotesBackup('[{"title":"no-id"}]'), isNull);
  });
}
